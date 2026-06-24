import SwiftUI

/// Maps files/folders to a stable color & category by broad type.
enum FileColor {
    enum Kind: Hashable {
        case folder, code, media, document, archive, app, data, other
    }

    private static let code: Set<String> = ["swift","js","ts","tsx","jsx","py","rb","go","rs","c","cpp","h","java","kt","sh","json","yml","yaml","html","css","scss"]
    private static let media: Set<String> = ["png","jpg","jpeg","gif","heic","webp","mp4","mov","avi","mkv","mp3","wav","aac","flac","svg","psd"]
    private static let document: Set<String> = ["pdf","doc","docx","xls","xlsx","ppt","pptx","txt","md","pages","numbers","key"]
    private static let archive: Set<String> = ["zip","tar","gz","tgz","xz","rar","7z","dmg","iso","pkg"]
    private static let app: Set<String> = ["app","framework","dylib","so","a"]
    private static let data: Set<String> = ["db","sqlite","sql","csv","log","img","raw","bin"]

    static func kind(for node: FileNode) -> Kind {
        if node.isDirectory { return .folder }
        let ext = node.fileExtension
        if code.contains(ext) { return .code }
        if media.contains(ext) { return .media }
        if document.contains(ext) { return .document }
        if archive.contains(ext) { return .archive }
        if app.contains(ext) { return .app }
        if data.contains(ext) { return .data }
        return .other
    }

    static func color(forKind kind: Kind) -> Color {
        switch kind {
        case .folder:   return Color(red: 0.30, green: 0.55, blue: 0.92)
        case .code:     return Color(red: 0.36, green: 0.78, blue: 0.55)
        case .media:    return Color(red: 0.93, green: 0.55, blue: 0.30)
        case .document: return Color(red: 0.55, green: 0.50, blue: 0.92)
        case .archive:  return Color(red: 0.88, green: 0.40, blue: 0.45)
        case .app:      return Color(red: 0.40, green: 0.74, blue: 0.86)
        case .data:     return Color(red: 0.80, green: 0.72, blue: 0.36)
        case .other:    return Color(red: 0.55, green: 0.58, blue: 0.62)
        }
    }

    static func color(for node: FileNode) -> Color { color(forKind: kind(for: node)) }

    static func label(for kind: Kind) -> String {
        switch kind {
        case .folder:   return "Folders"
        case .code:     return "Code"
        case .media:    return "Photos & Video"
        case .document: return "Documents"
        case .archive:  return "Archives"
        case .app:      return "Apps & Binaries"
        case .data:     return "Data"
        case .other:    return "Other"
        }
    }
}
