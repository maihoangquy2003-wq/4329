import Foundation

enum ZenithBypassHelper {
    static func mutateDataStrictly(data: Data, withID uniqueID: String, newName: String) -> Data {
        var mutableData = data
        
        // 1. Thử giải mã dạng JSON và thay đổi toàn bộ khóa định danh bên trong
        if var json = try? JSONSerialization.jsonObject(with: mutableData, options: .mutableContainers) as? [String: Any] {
            json["id"] = uniqueID
            json["name"] = newName
            json["uuid"] = UUID().uuidString
            // Thêm một trường rác ngẫu nhiên để thay đổi toàn bộ mã băm nhị phân (Binary Hash)
            json["zenith_salt"] = UUID().uuidString
            
            if let newData = try? JSONSerialization.data(withJSONObject: json, options: []) {
                return newData
            }
        }
        
        // 2. Nếu không phải JSON, thử dạng PropertyList (Plist)
        if var plist = try? PropertyListSerialization.propertyList(from: mutableData, options: .mutableContainersAndLeaves, format: nil) as? [String: Any] {
            plist["id"] = uniqueID
            plist["name"] = newName
            plist["uuid"] = UUID().uuidString
            
            if let newData = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
                return newData
            }
        }
        
        // 3. Phương án cuối cùng: Nếu file đóng gói dạng nhị phân thuần túy, ta nhồi thêm một byte ngẫu nhiên vào đuôi để đổi hoàn toàn mã hash
        mutableData.append(UUID().uuidString.data(using: .utf8) ?? Data())
        return mutableData
    }
}
