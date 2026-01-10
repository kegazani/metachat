import Foundation

struct JWTDecoder {
    static func decodePayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        
        var base64String = String(parts[1])
        
        let remainder = base64String.count % 4
        if remainder > 0 {
            base64String = base64String.padding(toLength: base64String.count + 4 - remainder, withPad: "=", startingAt: 0)
        }
        
        guard let data = Data(base64Encoded: base64String) else { return nil }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            return json
        } catch {
            return nil
        }
    }
    
    static func getUserId(from token: String) -> String? {
        guard let payload = decodePayload(token),
              let userId = payload["user_id"] else { return nil }
        return String(describing: userId)
    }
}

