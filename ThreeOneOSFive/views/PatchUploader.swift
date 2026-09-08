import Foundation

extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            self.append(data)
        }
    }
}

final class PatchUploader {
    static func upload(fileURL: URL, customName: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiURL = URL(string: "https://solitudepremium.click/ipa/proxy/apiaim.php") else { return }
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        let originalFilename = fileURL.lastPathComponent
        
        if let name = customName, !name.isEmpty {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"custom_name\"\r\n\r\n")
            body.appendString("\(name)\r\n")
        }
        
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"patch_file\"; filename=\"\(originalFilename)\"\r\n")
        body.appendString("Content-Type: application/octet-stream\r\n\r\n")
        
        if let fileData = try? Data(contentsOf: fileURL) {
            body.append(fileData)
        }
        
        body.appendString("\r\n--\(boundary)--\r\n")
        
        URLSession.shared.uploadTask(with: request, from: body) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let urlString = json["url"] as? String else {
                completion(.failure(NSError(domain: "UploadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid API response"])))
                return
            }
            
            completion(.success(urlString))
        }.resume()
    }
}
