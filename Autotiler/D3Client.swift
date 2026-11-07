import Foundation

/// d3 is a decision model: one request scores a fixed list of choices in a single forward pass,
/// so no text is generated and the prompt stays small.
enum D3Client {
    static let model = "d3:2b"
    static let minimumProbability = 0.5
    private static let endpoint = URL(string: "http://127.0.0.1:11434/v1/systemone")!

    struct Answer {
        let choice: String
        let probability: Double
    }

    /// Returns the highest-scoring key of `criteria` with its probability. The API's own `confidence` field is a
    /// margin over the runner-up, which reads low even for clear wins, so callers threshold on probability.
    /// Throws `modelUnavailable` if Ollama or the model is missing.
    static func choose(state: String, instructions: String, criteria: [String: String]) async throws -> Answer {
        let body: [String: Any] = [
            "model": model,
            "state": state,
            "questions": ["answer": ["type": "choice", "instructions": instructions, "criteria": criteria]],
        ]
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30  // first call loads the model into memory
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(Response.self, from: data),
              let answer = decoded.answers["answer"],
              let probability = answer.probabilities[answer.choice] else {
            throw InterpreterError.modelUnavailable
        }
        return Answer(choice: answer.choice, probability: probability)
    }

    private struct Response: Decodable {
        struct Item: Decodable {
            let choice: String
            let probabilities: [String: Double]
        }
        let answers: [String: Item]
    }
}
