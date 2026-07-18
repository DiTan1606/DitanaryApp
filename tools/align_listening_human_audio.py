#!/usr/bin/env python3
"""Align a narrated lesson to its existing sentence script and cut MP3 clips.

The script uses faster-whisper locally. It deliberately keeps the existing lesson
script as the source of truth, while using the narrated file only to find clean
sentence boundaries. Run it with the package directory on PYTHONPATH, for example:

  python3 -m pip install --target tmp/listening-tools faster-whisper

  PYTHONPATH=tmp/listening-tools python3 tools/align_listening_human_audio.py \
    --audio Data/listening/example/source.mp3 \
    --source Data/listening/example/source.txt \
    --manifest Data/listening/example/manifest.csv \
    --output Data/listening/example/audio_human \
    --report tmp/example-alignment.json
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
import unicodedata
from dataclasses import dataclass
from difflib import SequenceMatcher
from pathlib import Path

import av
import numpy as np
from faster_whisper import WhisperModel


WORD_PATTERN = re.compile(r"[a-z0-9]+(?:['-][a-z0-9]+)*", re.IGNORECASE)
NUMBER_WORDS = {
    "0": "zero",
    "1": "one",
    "2": "two",
    "3": "three",
    "4": "four",
    "5": "five",
    "6": "six",
    "7": "seven",
    "8": "eight",
    "9": "nine",
}


@dataclass(frozen=True)
class ScriptSentence:
    index: int
    text: str
    filename: str


@dataclass(frozen=True)
class RecognizedWord:
    text: str
    start: float
    end: float


def normalize_word(word: str) -> str:
    normalized = unicodedata.normalize("NFKD", word).lower().replace("’", "'")
    tokens = WORD_PATTERN.findall(normalized)
    if not tokens:
        return ""
    return NUMBER_WORDS.get(tokens[0], tokens[0])


def tokenize(text: str) -> list[str]:
    normalized = unicodedata.normalize("NFKD", text).lower().replace("’", "'")
    # Speech recognition usually emits the spoken parts separately, such as
    # "self care" and "to do", rather than retaining source punctuation.
    normalized = re.sub(r"[-–—/]+", " ", normalized)
    return [normalize_word(word) for word in WORD_PATTERN.findall(normalized) if normalize_word(word)]


def parse_source(path: Path) -> list[str]:
    sentences: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^\s*\d{1,3}\.\s+(.+?)\s*$", line)
        if match:
            sentences.append(match.group(1))
    if not sentences:
        raise ValueError(f"No numbered English sentences were found in {path}")
    return sentences


def parse_manifest(path: Path) -> list[str]:
    with path.open(newline="", encoding="utf-8") as handle:
        return [row["audio_file"] for row in csv.DictReader(handle)]


def transcribe(audio: Path, model_name: str) -> list[RecognizedWord]:
    model = WhisperModel(model_name, device="cpu", compute_type="int8")
    segments, _ = model.transcribe(
        str(audio),
        language="en",
        beam_size=5,
        word_timestamps=True,
        vad_filter=False,
        condition_on_previous_text=False,
    )

    words: list[RecognizedWord] = []
    for segment in segments:
        for word in segment.words or []:
            normalized = normalize_word(word.word)
            if normalized:
                words.append(RecognizedWord(normalized, float(word.start), float(word.end)))
    if not words:
        raise ValueError("Whisper did not return word timestamps")
    return words


def substitution_cost(reference: str, recognized: str) -> float:
    if reference == recognized:
        return 0.0
    # Small spelling/tokenization differences (e.g. "youre" vs "you're")
    # should still anchor a sentence, but count as a partial rather than exact match.
    if SequenceMatcher(a=reference, b=recognized).ratio() >= 0.82:
        return 0.35
    return 1.4


def align(reference: list[str], recognized: list[str]) -> list[tuple[int | None, int | None, float]]:
    """Return a global reference-to-recognition alignment.

    Each tuple contains the reference word index, ASR word index, and its local
    operation cost. Gaps have one of the two indices set to None.
    """

    delete_cost = 1.0
    insert_cost = 0.8
    rows, columns = len(reference) + 1, len(recognized) + 1
    costs = np.zeros((rows, columns), dtype=np.float32)
    moves = np.zeros((rows, columns), dtype=np.int8)

    costs[:, 0] = np.arange(rows) * delete_cost
    costs[0, :] = np.arange(columns) * insert_cost
    moves[1:, 0] = 1  # delete reference word
    moves[0, 1:] = 2  # insert recognized word

    for reference_index in range(1, rows):
        for recognized_index in range(1, columns):
            diagonal = costs[reference_index - 1, recognized_index - 1] + substitution_cost(
                reference[reference_index - 1], recognized[recognized_index - 1]
            )
            delete = costs[reference_index - 1, recognized_index] + delete_cost
            insert = costs[reference_index, recognized_index - 1] + insert_cost
            best = min(diagonal, delete, insert)
            costs[reference_index, recognized_index] = best
            moves[reference_index, recognized_index] = 0 if best == diagonal else (1 if best == delete else 2)

    output: list[tuple[int | None, int | None, float]] = []
    reference_index, recognized_index = len(reference), len(recognized)
    while reference_index or recognized_index:
        move = moves[reference_index, recognized_index]
        if move == 0:
            reference_index -= 1
            recognized_index -= 1
            output.append(
                (
                    reference_index,
                    recognized_index,
                    substitution_cost(reference[reference_index], recognized[recognized_index]),
                )
            )
        elif move == 1:
            reference_index -= 1
            output.append((reference_index, None, delete_cost))
        else:
            recognized_index -= 1
            output.append((None, recognized_index, insert_cost))
    return list(reversed(output))


def build_boundaries(
    sentences: list[ScriptSentence],
    recognized_words: list[RecognizedWord],
) -> tuple[list[dict[str, object]], list[float]]:
    reference_tokens: list[str] = []
    token_sentence_indices: list[int] = []
    for sentence in sentences:
        words = tokenize(sentence.text)
        reference_tokens.extend(words)
        token_sentence_indices.extend([sentence.index] * len(words))

    alignment = align(reference_tokens, [word.text for word in recognized_words])
    by_sentence: dict[int, list[tuple[int, float]]] = {sentence.index: [] for sentence in sentences}
    expected_by_sentence: dict[int, int] = {sentence.index: 0 for sentence in sentences}
    for sentence_index in token_sentence_indices:
        expected_by_sentence[sentence_index] += 1

    for reference_index, recognized_index, cost in alignment:
        if reference_index is None or recognized_index is None:
            continue
        if cost < 0.5:
            by_sentence[token_sentence_indices[reference_index]].append((recognized_index, cost))

    report: list[dict[str, object]] = []
    centers: list[float] = []
    for sentence in sentences:
        matches = by_sentence[sentence.index]
        expected_count = expected_by_sentence[sentence.index]
        if matches:
            first = recognized_words[matches[0][0]]
            last = recognized_words[matches[-1][0]]
            start, end = first.start, last.end
        else:
            start, end = 0.0, 0.0
        coverage = len(matches) / max(expected_count, 1)
        report.append(
            {
                "index": sentence.index,
                "text": sentence.text,
                "matched_words": len(matches),
                "expected_words": expected_count,
                "coverage": round(coverage, 3),
                "matched_start": round(start, 3),
                "matched_end": round(end, 3),
            }
        )
        centers.append((start + end) / 2 if matches else -1.0)

    # Turn word anchors into cut points. A boundary lies midway between the end
    # of one sentence and start of the next. This preserves a natural pause and
    # avoids leaking a word from its neighbor into the clip.
    cut_points: list[float] = []
    for left, right in zip(report, report[1:]):
        left_end = float(left["matched_end"])
        right_start = float(right["matched_start"])
        if left_end <= 0 or right_start <= 0 or right_start < left_end:
            cut_points.append(-1.0)
        else:
            cut_points.append((left_end + right_start) / 2)
    return report, cut_points


def load_pcm(audio: Path) -> tuple[np.ndarray, int]:
    container = av.open(str(audio))
    stream = container.streams.audio[0]
    sample_rate = stream.codec_context.sample_rate or 44100
    resampler = av.AudioResampler(format="fltp", layout="stereo", rate=sample_rate)
    pieces: list[np.ndarray] = []
    for frame in container.decode(stream):
        for converted in resampler.resample(frame):
            pieces.append(converted.to_ndarray())
    for converted in resampler.resample(None):
        pieces.append(converted.to_ndarray())
    container.close()
    if not pieces:
        raise ValueError("The source audio contained no decodable samples")
    return np.concatenate(pieces, axis=1), sample_rate


def write_mp3(samples: np.ndarray, sample_rate: int, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    output = av.open(str(destination), mode="w", format="mp3")
    stream = output.add_stream("libmp3lame", rate=sample_rate)
    stream.layout = "stereo"
    stream.bit_rate = 128_000

    frame_size = 1_152
    for offset in range(0, samples.shape[1], frame_size):
        chunk = np.ascontiguousarray(samples[:, offset : offset + frame_size])
        if not chunk.shape[1]:
            continue
        frame = av.AudioFrame.from_ndarray(chunk, format="fltp", layout="stereo")
        frame.sample_rate = sample_rate
        for packet in stream.encode(frame):
            output.mux(packet)
    for packet in stream.encode(None):
        output.mux(packet)
    output.close()


def validate_clip_ranges(report: list[dict[str, object]], cut_points: list[float], duration: float) -> list[tuple[float, float]]:
    ranges: list[tuple[float, float]] = []
    first_word_start = max(0.0, float(report[0]["matched_start"]) - 0.14)
    last_word_end = min(duration, float(report[-1]["matched_end"]) + 0.18)
    for position, entry in enumerate(report):
        # Narrations often have a spoken title or an outro that does not belong
        # to the lesson script. Keep only a little natural breathing room around
        # the first and final sentence rather than including those extras.
        start = first_word_start if position == 0 else cut_points[position - 1]
        end = last_word_end if position == len(report) - 1 else cut_points[position]
        if start < 0 or end < 0 or end - start < 0.35:
            index = int(entry["index"])
            raise ValueError(f"Cannot safely establish an audio range for sentence {index:02d}")
        ranges.append((start, end))
    return ranges


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--audio", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--model", default="base.en")
    parser.add_argument("--min-coverage", type=float, default=0.72)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    source_sentences = parse_source(args.source)
    filenames = parse_manifest(args.manifest)
    if len(source_sentences) != len(filenames):
        raise ValueError(
            f"The source has {len(source_sentences)} sentences but the manifest has {len(filenames)} rows"
        )
    sentences = [
        ScriptSentence(index=index, text=text, filename=filename)
        for index, (text, filename) in enumerate(zip(source_sentences, filenames), start=1)
    ]

    recognized_words = transcribe(args.audio, args.model)
    report, cut_points = build_boundaries(sentences, recognized_words)
    weak = [entry for entry in report if float(entry["coverage"]) < args.min_coverage]
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(
        json.dumps(
            {
                "audio": str(args.audio),
                "recognized_word_count": len(recognized_words),
                "sentences": report,
                "weak_sentences": [entry["index"] for entry in weak],
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    if weak:
        indices = ", ".join(f"{int(entry['index']):02d}" for entry in weak)
        raise ValueError(
            f"Alignment coverage is below {args.min_coverage:.0%} for sentence(s): {indices}. "
            f"Review {args.report} before cutting."
        )
    if args.dry_run:
        return

    pcm, sample_rate = load_pcm(args.audio)
    duration = pcm.shape[1] / sample_rate
    ranges = validate_clip_ranges(report, cut_points, duration)
    for sentence, (start, end), entry in zip(sentences, ranges, report):
        start_frame = max(0, int(round(start * sample_rate)))
        end_frame = min(pcm.shape[1], int(round(end * sample_rate)))
        clip = pcm[:, start_frame:end_frame]
        write_mp3(clip, sample_rate, args.output / Path(sentence.filename).name)
        entry["clip_start"] = round(start, 3)
        entry["clip_end"] = round(end, 3)
        entry["clip_duration"] = round(end - start, 3)

    args.report.write_text(
        json.dumps(
            {
                "audio": str(args.audio),
                "recognized_word_count": len(recognized_words),
                "sentences": report,
                "weak_sentences": [],
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
