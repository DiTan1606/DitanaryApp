from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".tmp" / "python-packages"))

import eng_to_ipa as ipa  # type: ignore


OUT_DIR = ROOT / "Data" / "listening" / "when_you_lose_motivation"
AUDIO_DIR = OUT_DIR / "audio"

TITLE = "When You Lose Motivation"
VI_TITLE = "Khi bạn mất động lực"
SERIES = "Stories of Life"
CEFR = "B1"
SOURCE_ID = "5"
AUDIO_STEM = "when_you_lose_motivation"

# The PDF and human narration are the source of truth for this lesson. Keep the
# wording aligned with the recording so dictation answers always match playback.
# The five numbered section headings remain as listening segments.
LESSON = [
    ("There will be moments when you feel you've lost your motivation and don't want to do anything.", "Sẽ có những lúc bạn cảm thấy mình đã mất động lực và chẳng muốn làm bất cứ điều gì."),
    ("Even people who are successful in life and work fall into the state.", "Ngay cả những người thành công trong cuộc sống và công việc cũng có lúc rơi vào trạng thái này."),
    ('However, let\'s see how they deal with this "down" mentality that helps them move forward and achieve great things!', 'Tuy nhiên, hãy xem họ đối mặt với trạng thái tinh thần "đi xuống" này như thế nào và cách đó giúp họ tiến về phía trước, đạt được những điều tuyệt vời ra sao.'),
    ("Motivation is one of the master keys that will motivate you and keep you going every day.", "Động lực là một trong những chiếc chìa khóa quan trọng sẽ thúc đẩy bạn và giúp bạn tiếp tục tiến bước mỗi ngày."),
    ("If you're not motivated, you'll tend to procrastinate about what has to be done.", "Nếu không có động lực, bạn sẽ có xu hướng trì hoãn những việc cần làm."),
    ("In the end, you will feel depressed, helpless and give up on everything or completely give up on the project/work you are working on.", "Cuối cùng, bạn sẽ cảm thấy chán nản, bất lực và từ bỏ mọi thứ hoặc hoàn toàn từ bỏ dự án hay công việc mình đang làm."),
    ("So, the following solutions will be five great ways for you to overcome this terrible state.", "Vì vậy, những giải pháp sau đây sẽ là năm cách tuyệt vời giúp bạn vượt qua trạng thái tồi tệ này."),
    ("Listen together!", "Hãy cùng lắng nghe nhé!"),
    ("One: Remember why you want to do it?", "Một: Hãy nhớ lý do bạn muốn làm điều đó."),
    ("If you feel a lack of motivation when you want to write an essay, try to think about why you want to do it.", "Nếu cảm thấy thiếu động lực khi muốn viết một bài luận, hãy thử nghĩ về lý do bạn muốn làm việc đó."),
    ("Your reasons for doing something are the driving force behind all your actions.", "Những lý do khiến bạn làm một việc chính là động lực đằng sau mọi hành động của bạn."),
    ("For example, why do people stop smoking?", "Ví dụ, tại sao mọi người lại bỏ thuốc lá?"),
    ("Most people stop smoking because they have a powerful reason.", "Hầu hết mọi người bỏ thuốc vì họ có một lý do đủ mạnh mẽ."),
    ("If they continue to smoke, they can suffer serious health problems that can affect their loved ones.", "Nếu tiếp tục hút thuốc, họ có thể gặp những vấn đề sức khỏe nghiêm trọng, gây ảnh hưởng đến người thân yêu."),
    ("So why do you do these jobs?", "Vậy tại sao bạn lại làm những công việc này?"),
    ("Do you know why you want to achieve your goal?", "Bạn có biết vì sao mình muốn đạt được mục tiêu không?"),
    ("Make sure your reasons are strong and realistic.", "Hãy đảm bảo rằng lý do của bạn đủ mạnh mẽ và thực tế."),
    ("When you feel unmotivated, think about why you want to do it.", "Khi cảm thấy mất động lực, hãy nghĩ về lý do bạn muốn làm điều đó."),
    ("Two: Visualize success if you do it and feel regret if you don't.", "Hai: Hãy hình dung thành công nếu bạn làm điều đó và cảm thấy hối tiếc nếu không làm."),
    ("Intuitive is a powerful tool that you have available and is completely free.", "Trực giác là một công cụ mạnh mẽ mà bạn có sẵn và hoàn toàn miễn phí."),
    ("You can think and imagine whatever, wherever and whenever you want.", "Bạn có thể suy nghĩ và tưởng tượng bất cứ điều gì, ở bất cứ đâu và bất cứ khi nào bạn muốn."),
    ("Try to imagine vividly, in as much detail as possible.", "Hãy cố gắng tưởng tượng thật sống động và chi tiết nhất có thể."),
    ("For example, your dream is to drive a Mercedes-Benz.", "Ví dụ, ước mơ của bạn là lái một chiếc Mercedes-Benz."),
    ("Picture vividly that you are driving that car.", "Hãy hình dung thật sống động rằng bạn đang lái chiếc xe đó."),
    ("Imagine the model you want, the color, the feeling when you sit inside, the smell of the leather upholstery, feel the steering and hear the rumbling engine sound.", "Hãy tưởng tượng mẫu xe bạn muốn, màu sắc, cảm giác khi ngồi bên trong, mùi da bọc ghế, cảm nhận vô lăng và nghe tiếng động cơ gầm vang."),
    ("The point is, when you imagine and visualize something in your mind, you will feel motivated to do it.", "Điều cốt lõi là khi tưởng tượng và hình dung một điều trong tâm trí, bạn sẽ cảm thấy có động lực để thực hiện nó."),
    ("When you dream about the car you want, you will create an inner motivation that you will work to have money to buy a car.", "Khi mơ về chiếc xe mình muốn, bạn sẽ tạo ra động lực từ bên trong để làm việc và có tiền mua xe."),
    ("Try doing this when you feel like procrastinating and don't have any motivation.", "Hãy thử cách này khi bạn muốn trì hoãn và không còn chút động lực nào."),
    ("Three: Create a supportive environment.", "Ba: Tạo một môi trường hỗ trợ."),
    ("Did you know your surroundings can greatly affect your mood?", "Bạn có biết môi trường xung quanh có thể ảnh hưởng rất lớn đến tâm trạng của mình không?"),
    ("Tell me, how do you feel when you have a wonderful stay in a most luxurious resort?", "Hãy thử nghĩ xem, bạn cảm thấy thế nào khi có một kỳ nghỉ tuyệt vời tại một khu nghỉ dưỡng sang trọng bậc nhất?"),
    ("Do you feel more valuable and have more confidence?", "Bạn có cảm thấy mình có giá trị hơn và tự tin hơn không?"),
    ("If you are always working with successful people who talk about business, you should also learn and join to talk about business topics.", "Nếu thường xuyên làm việc với những người thành công hay nói về kinh doanh, bạn cũng nên học hỏi và cùng tham gia nói chuyện về các chủ đề kinh doanh."),
    ("This is a good sign.", "Đây là một dấu hiệu tốt."),
    ("It's also a way to help you become active and use your surroundings to boost your energy levels.", "Đây cũng là cách giúp bạn trở nên năng động và tận dụng môi trường xung quanh để nâng cao mức năng lượng."),
    ("On the other hand, if you associate with negative people who are always spreading rumors and gossiping about others, you will also feel negative and unmotivated to work.", "Mặt khác, nếu giao du với những người tiêu cực, luôn tung tin đồn và nói xấu người khác, bạn cũng sẽ cảm thấy tiêu cực và mất động lực làm việc."),
    ("Sometimes you should also take care of your surroundings, like decorating your workspace, making it a place that makes you want to be there and try.", "Đôi khi bạn cũng nên chăm chút môi trường xung quanh, như trang trí nơi làm việc thành một nơi khiến bạn muốn ở đó và nỗ lực."),
    ("Remember, your surroundings are very important and it can affect you.", "Hãy nhớ rằng môi trường xung quanh rất quan trọng và nó có thể ảnh hưởng đến bạn."),
    ("So, change the surroundings to motivate yourself.", "Vì vậy, hãy thay đổi môi trường xung quanh để tạo động lực cho chính mình."),
    ("Four: Dream big, start small and act now.", "Bốn: Ước mơ lớn, bắt đầu nhỏ và hành động ngay."),
    ("This is a powerful principle if you apply it to your life.", "Đây là một nguyên tắc mạnh mẽ nếu bạn áp dụng nó vào cuộc sống."),
    ("When you dream, you have to dream big so that your dreams can inspire you.", "Khi mơ ước, hãy dám mơ lớn để những ước mơ ấy có thể truyền cảm hứng cho bạn."),
    ("However, when you start, you have to start small because this will make it a habit so that you automatically take constant action every day.", "Tuy nhiên, khi bắt đầu, bạn cần bắt đầu từ việc nhỏ vì điều này sẽ biến nó thành thói quen để bạn tự động hành động đều đặn mỗi ngày."),
    ("When your motivation is lost, start small, take the smallest steps, and develop from there.", "Khi mất động lực, hãy bắt đầu từ việc nhỏ, thực hiện những bước nhỏ nhất rồi phát triển dần từ đó."),
    ("For example, if you want to exercise and work out five days a week, try to plan and start slowly.", "Ví dụ, nếu muốn tập thể dục năm ngày mỗi tuần, hãy thử lập kế hoạch và bắt đầu từ từ."),
    ("Even if it's just five minutes a day, commit to doing it right and just do it.", "Dù chỉ là năm phút mỗi ngày, hãy cam kết thực hiện nghiêm túc và bắt tay vào làm."),
    ("Once you get motivated, you will get more motivated and go to higher levels.", "Khi đã có động lực, bạn sẽ có thêm động lực và tiến lên những cấp độ cao hơn."),
    ("Five: Take a rest.", "Năm: Hãy nghỉ ngơi."),
    ("Sometimes you just want to rest.", "Đôi khi bạn chỉ muốn nghỉ ngơi."),
    ("Remember, success is not a destination, it is a journey that you need to go through a long time.", "Hãy nhớ rằng thành công không phải là đích đến; đó là một hành trình dài."),
    ("This is not a sprint, but a marathon.", "Đây không phải là một cuộc chạy nước rút mà là một cuộc chạy marathon."),
    ("Many people mistake success as doing something great and success will come overnight.", "Nhiều người lầm tưởng thành công là làm được điều gì đó lớn lao và nghĩ rằng nó sẽ đến chỉ sau một đêm."),
    ("The truth is the opposite.", "Sự thật hoàn toàn ngược lại."),
    ("Almost all successful people who have achieved great results are able to do so because they persist long enough, they take consistent action and, of course, they never give up.", "Hầu hết những người thành công đạt được kết quả lớn đều làm được như vậy vì họ kiên trì đủ lâu, hành động nhất quán và tất nhiên là không bao giờ bỏ cuộc."),
    ("It is not something that can be created in a few days, not weeks, and not even months.", "Thành công không phải là thứ có thể tạo nên trong vài ngày, vài tuần hay thậm chí vài tháng."),
    ("True success takes years to build.", "Thành công thực sự cần nhiều năm để gây dựng."),
    ("So make sure you get enough rest and rest when you need it.", "Vì vậy, hãy đảm bảo rằng bạn nghỉ ngơi đầy đủ và nghỉ khi cần."),
    ("You need to understand your abilities and to what extent you can do.", "Bạn cần hiểu khả năng của mình và mức độ mình có thể làm được đến đâu."),
    ("If you're done with work, you can reward yourself by taking a rest.", "Nếu đã hoàn thành công việc, bạn có thể tự thưởng cho mình bằng cách nghỉ ngơi."),
    ('You find that after resting, you will be more energetic, active and ready to "fight" again.', 'Bạn sẽ nhận ra rằng sau khi nghỉ ngơi, mình sẽ tràn đầy năng lượng hơn, năng động hơn và sẵn sàng "chiến đấu" trở lại.'),
]


IPA_OVERRIDES = {
    "mercedes-benz": "mərˈseɪdiz bɛnz",
    "mercedes": "mərˈseɪdiz",
    "benz": "bɛnz",
    "upholstery": "əpˈhoʊlstəri",
    "workspace": "ˈwɝkˌspeɪs",
    "unmotivated": "ənˈmoʊtəˌveɪtɪd",
    "intuitive": "ɪnˈtuətɪv",
}


def clean_ipa(text: str) -> str:
    normalized = text.replace("’", "'").replace("“", '"').replace("”", '"').replace("/", " ")
    converted = ipa.convert(normalized)
    for word, value in IPA_OVERRIDES.items():
        converted = re.sub(rf"\b{re.escape(word)}\*?\b", value, converted, flags=re.IGNORECASE)
    phonetic_corrections = {
        "sˈmoʊkɪŋ": "ˈsmoʊkɪŋ",
        "sˈmɔləst": "ˈsmɔləst",
        "sˈloʊli": "ˈsloʊli",
        "əˈpoʊlstəri": "əpˈhoʊlstəri",
    }
    for old, new in phonetic_corrections.items():
        converted = converted.replace(old, new)
    converted = converted.replace('"', "").replace("*", "")
    converted = re.sub(r"\s+", " ", converted).strip()
    return f"/{converted}/"


def build_source() -> str:
    lines = [TITLE, f"Series: {SERIES}", f"CEFR: {CEFR}", ""]
    lines.extend(f"{index:02d}. {english}" for index, (english, _) in enumerate(LESSON, 1))
    return "\n".join(lines) + "\n"


def build_review(approved: bool) -> str:
    lines = [
        f"# {TITLE}",
        "",
        f"- Series: {SERIES}",
        f"- Vietnamese title: {VI_TITLE}",
        f"- CEFR: {CEFR}",
        f"- Segments: {len(LESSON)}",
        f"- Status: {'Approved - audio generated' if approved else 'Draft - awaiting approval before audio generation'}",
        "",
    ]
    for index, (english, vietnamese) in enumerate(LESSON, 1):
        lines.extend(
            [
                f"## {index:02d}",
                "",
                f"**EN:** {english}",
                "",
                f"**VI:** {vietnamese}",
                "",
                f"**IPA:** {clean_ipa(english)}",
                "",
            ]
        )
    return "\n".join(lines).rstrip() + "\n"


def generate_gtts_audio() -> None:
    from gtts import gTTS  # type: ignore

    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    for index, (english, _) in enumerate(LESSON, 1):
        path = AUDIO_DIR / f"{SOURCE_ID}_{index:02d}_{AUDIO_STEM}.mp3"
        if path.exists() and path.stat().st_size > 0:
            continue
        gTTS(text=english, lang="en", tld="com", slow=False).save(path)
        print(f"Generated {path.name}")


def write_manifest() -> None:
    manifest_path = OUT_DIR / "manifest.csv"
    with manifest_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(
            ["lesson_id", "title", "cefr", "index", "audio_file", "english", "vietnamese", "ipa"]
        )
        for index, (english, vietnamese) in enumerate(LESSON, 1):
            writer.writerow(
                [
                    SOURCE_ID,
                    TITLE,
                    CEFR,
                    index,
                    f"audio/{SOURCE_ID}_{index:02d}_{AUDIO_STEM}.mp3",
                    english,
                    vietnamese,
                    clean_ipa(english),
                ]
            )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--generate-audio", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "source.txt").write_text(build_source(), encoding="utf-8")
    if args.generate_audio:
        generate_gtts_audio()
        write_manifest()
    approved = args.generate_audio or (OUT_DIR / "manifest.csv").exists()
    (OUT_DIR / "review.md").write_text(build_review(approved), encoding="utf-8")
    print(f"Wrote draft to {OUT_DIR}")
    print(f"Segments: {len(LESSON)}")


if __name__ == "__main__":
    main()
