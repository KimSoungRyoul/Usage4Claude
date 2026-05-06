//
//  ShapeIconRenderer.swift
//  Usage4Claude
//
//  Created by Claude Code on 2025-12-18.
//  Copyright © 2025 f-is-h. All rights reserved.
//

import AppKit
import SwiftUI

/// 形状图标渲染器
/// 负责绘制非圆形图标（矩形、菱形、六边形）的进度环
class ShapeIconRenderer {

    // MARK: - Helper Methods

    /// 计算单色主题下的不透明度（基于百分比）
    /// - Parameter percentage: 使用百分比 (0-100)
    /// - Returns: 不透明度 (0.8-1.0)
    static func monochromeOpacity(for percentage: Double) -> CGFloat {
        if percentage <= 50 {
            return 0.8
        } else if percentage <= 75 {
            return 0.9
        } else {
            return 1.0
        }
    }

    // MARK: - Shape Drawing Methods

    /// 绘制圆角正方形进度环和百分比（用于 Opus）
    /// - Parameters:
    ///   - rect: 绘制区域
    ///   - percentage: 使用百分比
    ///   - isMonochrome: 是否为单色模式
    ///   - button: 状态栏按钮（用于获取颜色）
    ///   - removeBackground: 是否移除背景填充
    static func drawRoundedSquareWithPercentage(in rect: NSRect, percentage: Double, isMonochrome: Bool, button: NSStatusBarButton?, removeBackground: Bool = false) {
        let cornerRadius: CGFloat = 3.0
        let borderWidth: CGFloat = 1.5
        let progressWidth: CGFloat = 2.5  // 进度线条加粗
        let center = NSPoint(x: rect.midX, y: rect.midY)

        // 1. 绘制背景填充（彩色背景模式）
        if !removeBackground && !isMonochrome {
            let backgroundFillPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            NSColor.white.withAlphaComponent(0.5).setFill()
            backgroundFillPath.fill()
        }

        // 2. 绘制背景边框
        let backgroundPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        if isMonochrome {
            NSColor.controlTextColor.withAlphaComponent(0.3).setStroke()
        } else {
            NSColor.gray.withAlphaComponent(0.5).setStroke()
        }
        backgroundPath.lineWidth = borderWidth
        backgroundPath.stroke()

        // 2. 绘制进度边框（顺时针，从12点位置开始）
        if percentage > 0 {
            // 计算圆角正方形的实际周长
            // 周长 = 4条直线段 + 4个圆角弧
            // 直线段总长 = 4 * (边长 - 2*cornerRadius)
            // 圆角弧总长 = 4 * (π*cornerRadius/2) = 2*π*cornerRadius
            let straightLength = 4 * (rect.width - 2 * cornerRadius)
            let arcLength = 2 * CGFloat.pi * cornerRadius
            let perimeter = straightLength + arcLength

            // 计算进度长度
            // 使用渐进式减法：减去的长度随百分比线性增加，在50%时完成完整减法
            // < 50%时：平滑增长，减去量从0逐步到progressWidth
            // >= 50%时：完全精确，始终减去完整progressWidth
            // = 100%时不减去因为会使用.butt平头（无延伸）
            let baseProgressLength = perimeter * CGFloat(percentage / 100.0)
            let progressLength = percentage >= 100 ? baseProgressLength : (baseProgressLength - progressWidth * min(1.0, CGFloat(percentage / 50.0)))

            // 手动构建从12点开始顺时针的路径
            let progressPath = NSBezierPath()

            // 从12点位置（顶边中间）开始
            let startPoint = NSPoint(x: rect.midX, y: rect.maxY)
            progressPath.move(to: startPoint)

            // 顺时针绘制：12点 → 3点 → 6点 → 9点 → 回到12点
            // 右上角（需要考虑圆角）
            progressPath.line(to: NSPoint(x: rect.maxX - cornerRadius, y: rect.maxY))
            progressPath.appendArc(
                withCenter: NSPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius,
                startAngle: 90,
                endAngle: 0,
                clockwise: true
            )

            // 右边到右下角
            progressPath.line(to: NSPoint(x: rect.maxX, y: rect.minY + cornerRadius))
            progressPath.appendArc(
                withCenter: NSPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: 0,
                endAngle: 270,
                clockwise: true
            )

            // 底边到左下角
            progressPath.line(to: NSPoint(x: rect.minX + cornerRadius, y: rect.minY))
            progressPath.appendArc(
                withCenter: NSPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: 270,
                endAngle: 180,
                clockwise: true
            )

            // 左边到左上角
            progressPath.line(to: NSPoint(x: rect.minX, y: rect.maxY - cornerRadius))
            progressPath.appendArc(
                withCenter: NSPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius,
                startAngle: 180,
                endAngle: 90,
                clockwise: true
            )

            // 顶边回到起点
            progressPath.line(to: startPoint)

            // 使用dash pattern绘制
            // < 100%时使用负phase让起点处预先绘制半个圆头，使减去的lineWidth均匀分布在两端
            let phase: CGFloat = percentage >= 100 ? 0 : -progressWidth / 2
            let pattern: [CGFloat] = [progressLength, perimeter - progressLength]
            progressPath.setLineDash(pattern, count: 2, phase: phase)
            progressPath.lineWidth = progressWidth
            // 100%时使用平头让图形完美闭合，其他进度使用圆头
            progressPath.lineCapStyle = percentage >= 100 ? .butt : .round

            if isMonochrome {
                let opacity = monochromeOpacity(for: percentage)
                NSColor.controlTextColor.withAlphaComponent(opacity).setStroke()
            } else {
                UsageColorScheme.opusWeeklyColorAdaptive(percentage, for: button).setStroke()
            }
            progressPath.stroke()
        }

        // 3. 绘制百分比文字（字体大小随 rect 比例调整）
        let percentageText = "\(Int(percentage))"
        let percentageFontSize: CGFloat = percentage >= 100 ? rect.width * (5.0 / 16.0) : rect.width * (7.2 / 16.0)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: percentageFontSize, weight: percentage >= 100 ? .bold : .semibold),
            .foregroundColor: NSColor.black
        ]
        let textSize = percentageText.size(withAttributes: attributes)
        let textRect = NSRect(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2, width: textSize.width, height: textSize.height)
        percentageText.draw(in: textRect, withAttributes: attributes)
    }

    /// 绘制菱形进度环和百分比（用于 Sonnet - 45度旋转的正方形）
    /// - Parameters:
    ///   - rect: 绘制区域
    ///   - percentage: 使用百分比
    ///   - isMonochrome: 是否为单色模式
    ///   - button: 状态栏按钮（用于获取颜色）
    ///   - removeBackground: 是否移除背景填充
    static func drawDiamondWithPercentage(in rect: NSRect, percentage: Double, isMonochrome: Bool, button: NSStatusBarButton?, removeBackground: Bool = false) {
        // 完全复制Opus的参数设置
        let cornerRadius: CGFloat = 3.0
        let borderWidth: CGFloat = 1.5
        let progressWidth: CGFloat = 2.5  // 进度线条加粗
        let cutSize: CGFloat = 3.5  // 右上角斜切大小（微调小一点）
        let center = NSPoint(x: rect.midX, y: rect.midY)

        // 创建右上角斜切的圆角矩形路径（与Opus相同，只是右上角砍掉）
        func createChamferedRectPath(_ rect: NSRect) -> NSBezierPath {
            let path = NSBezierPath()

            // 从左下角开始（带圆角）
            path.move(to: NSPoint(x: rect.minX, y: rect.minY + cornerRadius))
            path.appendArc(
                withCenter: NSPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: 180,
                endAngle: 270,
                clockwise: false
            )

            // 底边到右下角（带圆角）
            path.line(to: NSPoint(x: rect.maxX - cornerRadius, y: rect.minY))
            path.appendArc(
                withCenter: NSPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: 270,
                endAngle: 0,
                clockwise: false
            )

            // 右边到斜切位置
            path.line(to: NSPoint(x: rect.maxX, y: rect.maxY - cutSize))

            // 斜切线
            path.line(to: NSPoint(x: rect.maxX - cutSize, y: rect.maxY))

            // 顶边到左上角（带圆角）
            path.line(to: NSPoint(x: rect.minX + cornerRadius, y: rect.maxY))
            path.appendArc(
                withCenter: NSPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius,
                startAngle: 90,
                endAngle: 180,
                clockwise: false
            )

            // 回到起点
            path.close()

            return path
        }

        // 1. 绘制背景填充（彩色背景模式）
        if !removeBackground && !isMonochrome {
            let backgroundFillPath = createChamferedRectPath(rect)
            NSColor.white.withAlphaComponent(0.5).setFill()
            backgroundFillPath.fill()
        }

        // 2. 绘制背景边框（与Opus完全一致）
        let backgroundPath = createChamferedRectPath(rect)
        if isMonochrome {
            NSColor.controlTextColor.withAlphaComponent(0.3).setStroke()
        } else {
            NSColor.gray.withAlphaComponent(0.5).setStroke()
        }
        backgroundPath.lineWidth = borderWidth
        backgroundPath.stroke()

        // 2. 绘制进度边框（顺时针，从12点位置开始）
        if percentage > 0 {
            // 手动构建从12点开始顺时针的路径（带右上角斜切）
            let progressPath = NSBezierPath()

            // 从12点位置（顶边中间）开始
            let startPoint = NSPoint(x: rect.midX, y: rect.maxY)
            progressPath.move(to: startPoint)

            // 顺时针绘制：12点 → 右上角斜切 → 3点 → 6点 → 9点 → 回到12点
            // 顶边到右上角斜切位置
            progressPath.line(to: NSPoint(x: rect.maxX - cutSize, y: rect.maxY))

            // 右上角斜切线
            progressPath.line(to: NSPoint(x: rect.maxX, y: rect.maxY - cutSize))

            // 右边到右下角
            progressPath.line(to: NSPoint(x: rect.maxX, y: rect.minY + cornerRadius))
            progressPath.appendArc(
                withCenter: NSPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: 0,
                endAngle: 270,
                clockwise: true
            )

            // 底边到左下角
            progressPath.line(to: NSPoint(x: rect.minX + cornerRadius, y: rect.minY))
            progressPath.appendArc(
                withCenter: NSPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: 270,
                endAngle: 180,
                clockwise: true
            )

            // 左边到左上角
            progressPath.line(to: NSPoint(x: rect.minX, y: rect.maxY - cornerRadius))
            progressPath.appendArc(
                withCenter: NSPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
                radius: cornerRadius,
                startAngle: 180,
                endAngle: 90,
                clockwise: true
            )

            // 顶边回到起点
            progressPath.line(to: startPoint)

            // 计算斜切正方形的实际周长
            // 基于Opus的圆角正方形周长，然后调整斜切部分：
            // 1. Opus周长 = 4条直线段 + 4个圆角弧
            let opusStraightLength = 4 * (rect.width - 2 * cornerRadius)
            let opusArcLength = 2 * CGFloat.pi * cornerRadius
            let opusPerimeter = opusStraightLength + opusArcLength

            // 2. Sonnet的右上角斜切导致：
            //    - 移除了一个90度圆角弧: -cornerRadius * π/2
            //    - 顶边从(width-2*corner)变成(width-corner-cut): +cornerRadius-cutSize
            //    - 右边从(width-2*corner)变成(width-corner-cut): +cornerRadius-cutSize
            //    - 增加了斜切线: +cutSize * sqrt(2)
            //    总计: 2*cornerRadius - 2*cutSize + cutSize*sqrt(2) - cornerRadius*π/2
            let cornerArcReduction = -cornerRadius * .pi / 2
            let edgeAdjustment = 2.0 * cornerRadius
            let cutAdjustment = cutSize * (sqrt(2.0) - 2.0)
            let perimeter = opusPerimeter + cornerArcReduction + edgeAdjustment + cutAdjustment

            // 计算进度长度
            // 使用渐进式减法：减去的长度随百分比线性增加，在50%时完成完整减法
            // < 50%时：平滑增长，减去量从0逐步到progressWidth
            // >= 50%时：完全精确，始终减去完整progressWidth
            // = 100%时不减去因为会使用.butt平头（无延伸）
            let baseProgressLength = perimeter * CGFloat(percentage / 100.0)
            let progressLength = percentage >= 100 ? baseProgressLength : (baseProgressLength - progressWidth * min(1.0, CGFloat(percentage / 50.0)))

            // 使用dash pattern绘制
            // < 100%时使用负phase让起点处预先绘制半个圆头，使减去的lineWidth均匀分布在两端
            let phase: CGFloat = percentage >= 100 ? 0 : -progressWidth / 2
            let pattern: [CGFloat] = [progressLength, perimeter - progressLength]
            progressPath.setLineDash(pattern, count: 2, phase: phase)
            progressPath.lineWidth = progressWidth
            // 100%时使用平头让图形完美闭合，其他进度使用圆头
            progressPath.lineCapStyle = percentage >= 100 ? .butt : .round

            if isMonochrome {
                let opacity = monochromeOpacity(for: percentage)
                NSColor.controlTextColor.withAlphaComponent(opacity).setStroke()
            } else {
                UsageColorScheme.sonnetWeeklyColorAdaptive(percentage, for: button).setStroke()
            }
            progressPath.stroke()
        }

        // 3. 绘制百分比文字（与Opus完全一致，字号随 rect 比例缩放）
        let percentageText = "\(Int(percentage))"
        let percentageFontSize: CGFloat = percentage >= 100 ? rect.width * (5.0 / 16.0) : rect.width * (7.2 / 16.0)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: percentageFontSize, weight: percentage >= 100 ? .bold : .semibold),
            .foregroundColor: NSColor.black
        ]
        let textSize = percentageText.size(withAttributes: attributes)
        let textRect = NSRect(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2, width: textSize.width, height: textSize.height)
        percentageText.draw(in: textRect, withAttributes: attributes)
    }

    /// 绘制平顶六边形进度环和百分比（用于 Extra Usage）
    /// - Parameters:
    ///   - center: 中心点
    ///   - size: 六边形大小
    ///   - percentage: 使用百分比
    ///   - isMonochrome: 是否为单色模式
    ///   - button: 状态栏按钮（用于获取颜色）
    ///   - removeBackground: 是否移除背景填充
    static func drawHexagonWithPercentage(center: NSPoint, size: CGFloat, percentage: Double, isMonochrome: Bool, button: NSStatusBarButton?, removeBackground: Bool = false, colorOverride: NSColor? = nil, displayText: String? = nil) {
        let radius = size / 2
        let borderWidth: CGFloat = 1.5
        let progressWidth: CGFloat = 2.5  // 进度线条加粗

        // 文字準備 — 默认显示百分比，displayText 提供时使用（如 amount 模式下显示 "$26"）
        let percentageText = displayText ?? "\(Int(percentage))"
        // 文字超过 2 字符时（如 "$26", "100"）使用更小字号避免溢出
        let percentageFontSize: CGFloat = percentageText.count >= 3 ? 5.0 : 7.2
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: percentageFontSize, weight: percentageText.count >= 3 ? .bold : .semibold),
            .foregroundColor: NSColor.black
        ]

        // 创建平顶六边形路径（flat top - 上下两边是平的）
        let hexagonPath = NSBezierPath()
        for i in 0..<6 {
            let angle = CGFloat(i) * CGFloat.pi / 3.0  // 保持平顶方向
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            if i == 0 {
                hexagonPath.move(to: NSPoint(x: x, y: y))
            } else {
                hexagonPath.line(to: NSPoint(x: x, y: y))
            }
        }
        hexagonPath.close()

        // 1. 绘制背景填充（彩色背景模式）
        if !removeBackground && !isMonochrome {
            NSColor.white.withAlphaComponent(0.5).setFill()
            hexagonPath.fill()
        }

        // 2. 绘制背景边框
        if isMonochrome {
            NSColor.controlTextColor.withAlphaComponent(0.3).setStroke()
        } else {
            NSColor.gray.withAlphaComponent(0.5).setStroke()
        }
        hexagonPath.lineWidth = borderWidth
        hexagonPath.lineJoinStyle = .round
        hexagonPath.stroke()

        // 2. 绘制进度边框
        if percentage > 0 {
            // 计算六边形周长
            let sideLength = radius  // 正六边形每边长度等于半径
            let perimeter = sideLength * 6

            // 计算进度长度
            // 使用渐进式减法：减去的长度随百分比线性增加，在50%时完成完整减法
            // < 50%时：平滑增长，减去量从0逐步到progressWidth
            // >= 50%时：完全精确，始终减去完整progressWidth
            // = 100%时不减去因为会使用.butt平头（无延伸）
            let baseProgressLength = perimeter * CGFloat(percentage / 100.0)
            let progressLength = percentage >= 100 ? baseProgressLength : (baseProgressLength - progressWidth * min(1.0, CGFloat(percentage / 50.0)))

            // 手动构建从12点钟顶部开始的顺时针路径
            // 首先计算6个顶点位置（保持平顶方向）
            var vertices: [NSPoint] = []
            for i in 0..<6 {
                let angle = CGFloat(i) * CGFloat.pi / 3.0
                let x = center.x + radius * cos(angle)
                let y = center.y + radius * sin(angle)
                vertices.append(NSPoint(x: x, y: y))
            }
            // vertices[0] = 3点 (右)
            // vertices[1] = 1点 (右上)
            // vertices[2] = 11点 (左上)
            // vertices[3] = 9点 (左)
            // vertices[4] = 7点 (左下)
            // vertices[5] = 5点 (右下)

            // 从12点钟位置开始（顶边中点，在vertices[1]和vertices[2]之间）
            let topMidpoint = NSPoint(
                x: (vertices[1].x + vertices[2].x) / 2,
                y: (vertices[1].y + vertices[2].y) / 2
            )

            let progressHexagon = NSBezierPath()
            progressHexagon.move(to: topMidpoint)

            // 顺时针方向：12点 → 1点 → 3点 → 5点 → 7点 → 9点 → 11点 → 回到12点
            progressHexagon.line(to: vertices[1])  // 到1点顶点
            progressHexagon.line(to: vertices[0])  // 到3点顶点
            progressHexagon.line(to: vertices[5])  // 到5点顶点
            progressHexagon.line(to: vertices[4])  // 到7点顶点
            progressHexagon.line(to: vertices[3])  // 到9点顶点
            progressHexagon.line(to: vertices[2])  // 到11点顶点
            progressHexagon.line(to: topMidpoint)  // 回到12点

            // 使用dash pattern绘制
            // < 100%时使用负phase让起点处预先绘制半个圆头，使减去的lineWidth均匀分布在两端
            let phase: CGFloat = percentage >= 100 ? 0 : -progressWidth / 2
            let pattern: [CGFloat] = [progressLength, perimeter - progressLength]
            progressHexagon.setLineDash(pattern, count: 2, phase: phase)
            progressHexagon.lineWidth = progressWidth
            // 100%时使用平头让图形完美闭合，其他进度使用圆头
            progressHexagon.lineCapStyle = percentage >= 100 ? .butt : .round
            progressHexagon.lineJoinStyle = .round

            if isMonochrome {
                let opacity = monochromeOpacity(for: percentage)
                NSColor.controlTextColor.withAlphaComponent(opacity).setStroke()
            } else if let colorOverride {
                colorOverride.setStroke()
            } else {
                UsageColorScheme.extraUsageColorAdaptive(percentage, for: button).setStroke()
            }
            progressHexagon.stroke()
        }

        // 3. 绘制百分比文字
        let textSize = percentageText.size(withAttributes: textAttrs)
        let textRect = NSRect(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2, width: textSize.width, height: textSize.height)
        percentageText.draw(in: textRect, withAttributes: textAttrs)
    }

    // MARK: - Icon Creation Methods

    /// 创建圆角正方形图标（Opus）
    /// - Parameters:
    ///   - percentage: 使用百分比
    ///   - isMonochrome: 是否为单色模式
    ///   - button: 状态栏按钮
    ///   - removeBackground: 是否移除背景填充
    /// - Returns: 图标图像 (18×18)
    static func createVerticalRectangleIcon(percentage: Double, isMonochrome: Bool, button: NSStatusBarButton?, removeBackground: Bool = false) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(x: 0, y: 0, width: size.width, height: size.height).insetBy(dx: 2, dy: 2)
        drawRoundedSquareWithPercentage(in: rect, percentage: percentage, isMonochrome: isMonochrome, button: button, removeBackground: removeBackground)

        image.unlockFocus()
        image.isTemplate = isMonochrome
        return image
    }

    /// 创建菱形图标（Sonnet - 45度旋转的正方形）
    /// - Parameters:
    ///   - percentage: 使用百分比
    ///   - isMonochrome: 是否为单色模式
    ///   - button: 状态栏按钮
    ///   - removeBackground: 是否移除背景填充
    /// - Returns: 图标图像 (18×18)
    static func createHorizontalRectangleIcon(percentage: Double, isMonochrome: Bool, button: NSStatusBarButton?, removeBackground: Bool = false) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(x: 0, y: 0, width: size.width, height: size.height).insetBy(dx: 2, dy: 2)
        drawDiamondWithPercentage(in: rect, percentage: percentage, isMonochrome: isMonochrome, button: button, removeBackground: removeBackground)

        image.unlockFocus()
        image.isTemplate = isMonochrome
        return image
    }

    /// 创建平顶六边形图标（Extra Usage）
    /// - Parameters:
    ///   - percentage: 使用百分比
    ///   - isMonochrome: 是否为单色模式
    ///   - button: 状态栏按钮
    ///   - removeBackground: 是否移除背景（默认false）
    /// - Returns: 图标图像 (18×18)
    /// 기존 NSImage 위에 작은 텍스트 라벨을 얹어 새 NSImage 반환
    /// 멀티 계정 status item 에서 도형 스타일의 위에 계정명을 표시할 때 사용
    static func wrapWithTopLabel(_ contentImage: NSImage, label: String, isMonochrome: Bool) -> NSImage {
        let labelFont = NSFont.systemFont(ofSize: 8, weight: .regular)
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let labelSize = label.size(withAttributes: labelAttrs)

        let contentSize = contentImage.size
        let imageWidth = ceil(max(labelSize.width, contentSize.width)) + 4
        let imageHeight: CGFloat = max(22, ceil(labelSize.height) + ceil(contentSize.height))

        let image = NSImage(size: NSSize(width: imageWidth, height: imageHeight))
        image.lockFocus()

        // 위 라벨 (가운데)
        let labelY = imageHeight - labelSize.height - 1
        let labelRect = NSRect(
            x: (imageWidth - labelSize.width) / 2,
            y: labelY,
            width: labelSize.width,
            height: labelSize.height
        )
        label.draw(in: labelRect, withAttributes: labelAttrs)

        // 아래 content (가운데 아래 정렬)
        let contentX = (imageWidth - contentSize.width) / 2
        contentImage.draw(
            at: NSPoint(x: contentX, y: 0),
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )

        image.unlockFocus()
        image.isTemplate = isMonochrome
        return image
    }

    /// 多值 컴팩트 — 上方 한 라벨 + 下方 여러 값 가로 나열 (5h, 7d, ExtraUsage 등 동시 표시)
    /// - Parameters:
    ///   - label: 위쪽 라벨 (예: "Naver_TEAM")
    ///   - items: 아래 가로 나열 항목 (text, color)
    ///   - isMonochrome: template 모드
    static func createMultiValueCompactIcon(
        label: String,
        items: [(text: String, color: NSColor)],
        isMonochrome: Bool
    ) -> NSImage {
        let labelFont = NSFont.systemFont(ofSize: 8, weight: .regular)
        let valueFont = NSFont.systemFont(ofSize: 11, weight: .semibold)
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        let labelSize = label.size(withAttributes: labelAttrs)

        // 각 value 측정
        struct Measured {
            let text: String
            let attrs: [NSAttributedString.Key: Any]
            let size: NSSize
        }
        let measured: [Measured] = items.map { item in
            let attrs: [NSAttributedString.Key: Any] = [
                .font: valueFont,
                .foregroundColor: isMonochrome ? NSColor.controlTextColor : item.color
            ]
            return Measured(text: item.text, attrs: attrs, size: item.text.size(withAttributes: attrs))
        }

        let valueSpacing: CGFloat = 8
        let totalValueWidth = measured.reduce(0) { $0 + $1.size.width }
            + CGFloat(max(0, measured.count - 1)) * valueSpacing

        let imageWidth = ceil(max(labelSize.width, totalValueWidth)) + 6
        let imageHeight: CGFloat = 22
        let imageSize = NSSize(width: imageWidth, height: imageHeight)

        let image = NSImage(size: imageSize)
        image.lockFocus()

        // 上 label (가운데 정렬)
        let labelY = imageHeight - labelSize.height - 1
        let labelRect = NSRect(
            x: (imageWidth - labelSize.width) / 2,
            y: labelY,
            width: labelSize.width,
            height: labelSize.height
        )
        label.draw(in: labelRect, withAttributes: labelAttrs)

        // 下 values 가로 나열 (가운데 정렬)
        var x = (imageWidth - totalValueWidth) / 2
        for m in measured {
            let rect = NSRect(x: x, y: 0, width: m.size.width, height: m.size.height)
            m.text.draw(in: rect, withAttributes: m.attrs)
            x += m.size.width + valueSpacing
        }

        image.unlockFocus()
        image.isTemplate = isMonochrome
        return image
    }

    /// 创建紧凑风格图标（系统监控风 — 上方账号名 + 下方值）
    /// - 类似 macOS Stats / iStat Menus 中的 "CPU 30%" / "RAM 61%" 显示
    /// - 上方小字标签（账号名等），下方大字值（金额/百分比）
    /// - 值的颜色按 percentage 在绿→黄→红渐变
    /// - 宽度根据较长一行自动伸缩
    /// - Parameters:
    ///   - label: 上方小字（如 "Naver"）
    ///   - value: 下方大字（如 "$50 (11%)" 或 "14%"）
    ///   - valueColor: 值的颜色（彩色模式下使用）
    ///   - isMonochrome: 单色（template）模式
    /// - Returns: 高度 22px、宽度自适应的图标
    static func createCompactIcon(label: String, value: String, valueColor: NSColor, isMonochrome: Bool) -> NSImage {
        let labelFont = NSFont.systemFont(ofSize: 8, weight: .regular)
        let valueFont = NSFont.systemFont(ofSize: 11, weight: .semibold)

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: isMonochrome ? NSColor.controlTextColor : valueColor
        ]

        let labelSize = label.size(withAttributes: labelAttrs)
        let valueSize = value.size(withAttributes: valueAttrs)

        let imageWidth = ceil(max(labelSize.width, valueSize.width)) + 4
        let imageHeight: CGFloat = 22
        let imageSize = NSSize(width: imageWidth, height: imageHeight)

        let image = NSImage(size: imageSize)
        image.lockFocus()

        // 上方 label
        let labelY = imageHeight - labelSize.height - 1
        let labelRect = NSRect(
            x: (imageWidth - labelSize.width) / 2,
            y: labelY,
            width: labelSize.width,
            height: labelSize.height
        )
        label.draw(in: labelRect, withAttributes: labelAttrs)

        // 下方 value（绿→黄→红 색상 적용）
        let valueRect = NSRect(
            x: (imageWidth - valueSize.width) / 2,
            y: 0,
            width: valueSize.width,
            height: valueSize.height
        )
        value.draw(in: valueRect, withAttributes: valueAttrs)

        image.unlockFocus()
        image.isTemplate = isMonochrome
        return image
    }

    static func createHexagonIcon(percentage: Double, isMonochrome: Bool, button: NSStatusBarButton?, removeBackground: Bool = false, colorOverride: NSColor? = nil, displayText: String? = nil) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let center = NSPoint(x: size.width / 2, y: size.height / 2)
        drawHexagonWithPercentage(center: center, size: 16, percentage: percentage, isMonochrome: isMonochrome, button: button, removeBackground: removeBackground, colorOverride: colorOverride, displayText: displayText)

        image.unlockFocus()
        image.isTemplate = isMonochrome
        return image
    }

    // MARK: - Multi-Account Helpers (v3.1)

    /// 여러 계정의 (라벨, 값, 색)을 가로 나열한 menubar 아이콘
    /// 형식: "라벨1: 값1  라벨2: 값2  ..."
    static func createMultiAccountCompactIcon(
        items: [(label: String, value: String, color: NSColor)],
        isMonochrome: Bool
    ) -> NSImage {
        guard !items.isEmpty else {
            // empty placeholder
            let placeholder = NSImage(size: NSSize(width: 18, height: 18))
            placeholder.isTemplate = true
            return placeholder
        }

        let labelFont = NSFont.systemFont(ofSize: 9, weight: .medium)
        let valueFont = NSFont.systemFont(ofSize: 11, weight: .semibold)
        let labelColor = NSColor.secondaryLabelColor
        let separator: CGFloat = 6 // 계정 간 가로 간격
        let height: CGFloat = 22

        // 빈 라벨은 값만 단독 표시 — 활성 계정용 (가로 폭 절약)
        // 너비 계산
        var totalWidth: CGFloat = 0
        var sizes: [(labelW: CGFloat, valueW: CGFloat)] = []
        for item in items {
            let lw: CGFloat = item.label.isEmpty ? 0 : (item.label as NSString).size(withAttributes: [.font: labelFont]).width
            let vw = (item.value as NSString).size(withAttributes: [.font: valueFont]).width
            sizes.append((lw, vw))
            totalWidth += max(lw, vw) + separator
        }
        totalWidth -= separator // 마지막 separator 제거
        totalWidth += 4 // 좌우 여백

        let image = NSImage(size: NSSize(width: max(totalWidth, 18), height: height))
        image.lockFocus()

        var x: CGFloat = 2
        for (i, item) in items.enumerated() {
            let columnWidth = max(sizes[i].labelW, sizes[i].valueW)
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: labelFont,
                .foregroundColor: isMonochrome ? NSColor.labelColor : labelColor
            ]
            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: valueFont,
                .foregroundColor: isMonochrome ? NSColor.labelColor : item.color
            ]

            if item.label.isEmpty {
                // 라벨 없으면 값을 세로 중앙에 단독 배치
                let valueRect = NSRect(x: x, y: 5, width: columnWidth, height: 14)
                (item.value as NSString).draw(in: valueRect, withAttributes: valueAttrs)
            } else {
                // 라벨이 있으면 위 라벨 + 아래 값 (시스템 모니터 풍)
                let labelRect = NSRect(x: x, y: height - 11, width: columnWidth, height: 10)
                (item.label as NSString).draw(in: labelRect, withAttributes: labelAttrs)
                let valueRect = NSRect(x: x, y: 2, width: columnWidth, height: 12)
                (item.value as NSString).draw(in: valueRect, withAttributes: valueAttrs)
            }

            x += columnWidth + separator
        }

        image.unlockFocus()
        image.isTemplate = isMonochrome
        return image
    }

    /// 여러 NSImage를 가로로 합성한 새 NSImage 반환
    static func concatenateHorizontally(_ images: [NSImage], spacing: CGFloat = 4) -> NSImage {
        guard !images.isEmpty else {
            let img = NSImage(size: NSSize(width: 18, height: 18))
            img.isTemplate = true
            return img
        }
        let totalWidth = images.reduce(0) { $0 + $1.size.width } + spacing * CGFloat(max(0, images.count - 1))
        let height = images.map(\.size.height).max() ?? 22

        let result = NSImage(size: NSSize(width: totalWidth, height: height))
        result.lockFocus()
        var x: CGFloat = 0
        for img in images {
            let y = (height - img.size.height) / 2
            img.draw(at: NSPoint(x: x, y: y), from: .zero, operation: .sourceOver, fraction: 1.0)
            x += img.size.width + spacing
        }
        result.unlockFocus()
        // 모든 입력이 template 일 때만 template (아니면 색상 상실)
        result.isTemplate = images.allSatisfy { $0.isTemplate }
        return result
    }

    /// 기존 아이콘 우측에 색상 점들을 작게 추가
    static func appendDots(to baseIcon: NSImage, dotColors: [NSColor], isMonochrome: Bool) -> NSImage {
        guard !dotColors.isEmpty else { return baseIcon }
        let dotSize: CGFloat = 5
        let dotSpacing: CGFloat = 2
        let leadingGap: CGFloat = 4
        let dotsTotalWidth: CGFloat = CGFloat(dotColors.count) * dotSize
            + CGFloat(max(0, dotColors.count - 1)) * dotSpacing

        let totalWidth = baseIcon.size.width + leadingGap + dotsTotalWidth
        let height = max(baseIcon.size.height, dotSize)

        let result = NSImage(size: NSSize(width: totalWidth, height: height))
        result.lockFocus()
        baseIcon.draw(at: NSPoint(x: 0, y: (height - baseIcon.size.height) / 2),
                      from: .zero, operation: .sourceOver, fraction: 1.0)

        var x = baseIcon.size.width + leadingGap
        let dotY = (height - dotSize) / 2
        for color in dotColors {
            let path = NSBezierPath(ovalIn: NSRect(x: x, y: dotY, width: dotSize, height: dotSize))
            (isMonochrome ? NSColor.labelColor : color).setFill()
            path.fill()
            x += dotSize + dotSpacing
        }
        result.unlockFocus()
        result.isTemplate = isMonochrome
        return result
    }
}
