import UIKit

/// Chek rasmlarini saqlashdan oldin qayta ishlaydi — kattaligini kamaytiradi va siqadi.
/// Nega? Original foto 5–10 MB boʻlishi mumkin; bu bazani va CloudKit trafigini shishiradi.
enum ImageProcessor {

    /// Rasmni maksimal oʻlchamga moslab, JPEG sifatida siqilgan `Data` qaytaradi.
    static func compress(_ image: UIImage,
                         maxDimension: CGFloat = 1600,
                         quality: CGFloat = 0.7) -> Data? {
        image.downscaled(maxDimension: maxDimension).jpegData(compressionQuality: quality)
    }

    /// Xom `Data`'dan qayta ishlab, siqilgan `Data` qaytaradi (PhotosPicker natijasi uchun).
    static func compress(data: Data,
                         maxDimension: CGFloat = 1600,
                         quality: CGFloat = 0.7) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return compress(image, maxDimension: maxDimension, quality: quality)
    }
}

extension UIImage {
    /// Tomonlar nisbatini saqlab, eng uzun tomonni `maxDimension`ga kichraytiradi.
    func downscaled(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return self }
        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
