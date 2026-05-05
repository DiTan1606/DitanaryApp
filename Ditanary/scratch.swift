func calculateStrictSimilarity(target: String, input: String) -> Double {
    let targetWords = target.lowercased().components(separatedBy: .punctuationCharacters).joined().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    let inputWords = input.lowercased().components(separatedBy: .punctuationCharacters).joined().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    
    guard !targetWords.isEmpty else { return 0.0 }
    if inputWords.isEmpty { return 0.0 }
    
    let empty = [Int](repeating: 0, count: inputWords.count + 1)
    var last = [Int](0...inputWords.count)
    
    for (i, tWord) in targetWords.enumerated() {
        var current = [i + 1] + empty.dropFirst()
        for (j, iWord) in inputWords.enumerated() {
            if tWord == iWord {
                current[j + 1] = last[j]
            } else {
                current[j + 1] = min(last[j], current[j], last[j + 1]) + 1
            }
        }
        last = current
    }
    
    let distance = last.last ?? 0
    let maxLength = max(targetWords.count, inputWords.count)
    let matchPercentage = Double(maxLength - distance) / Double(maxLength)
    
    return max(0.0, matchPercentage * 100.0)
}
