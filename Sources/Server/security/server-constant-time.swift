import Foundation

public enum ServerConstantTime {
    public static func equals(
        _ lhs: String,
        _ rhs: String
    ) -> Bool {
        let left = Array(
            lhs.utf8
        )
        let right = Array(
            rhs.utf8
        )

        let maxCount = max(
            left.count,
            right.count
        )

        var difference = UInt64(
            left.count ^ right.count
        )

        for index in 0..<maxCount {
            let leftByte: UInt8 = index < left.count ? left[index] : 0
            let rightByte: UInt8 = index < right.count ? right[index] : 0

            difference |= UInt64(
                leftByte ^ rightByte
            )
        }

        return difference == 0
    }
}
