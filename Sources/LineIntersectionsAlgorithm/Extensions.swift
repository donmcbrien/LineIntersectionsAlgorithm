//
//  Extensions.swift
//  IntersectingLineSegments
//
//  Created by Don McBrien on 15/07/2021.
//

import Foundation
import RedBlackTree

//MARK: - CGPoint

extension CGPoint: CustomStringConvertible {
   public var description: String {
      return String(format: "(%6.3f, %6.3f)", x, y)
   }
}

extension CGPoint: Comparable, Hashable {
   public func hash(into hasher: inout Hasher) {
      hasher.combine(x)
      hasher.combine(y)
   }
   
   public static func == (lhs: CGPoint, rhs: CGPoint) -> Bool {
      return lhs.x == rhs.x &&
      lhs.y == rhs.y
   }
   
   public static func < (lhs: CGPoint, rhs: CGPoint) -> Bool {
      return lhs.y > rhs.y || (lhs.y == rhs.y && lhs.x < rhs.x)
   }
}

extension CGPoint: RedBlackTreeKeyProtocol {
   public static var duplicatesAllowed: Bool { return true }
   public static var duplicatesUseFIFO: Bool { return true }

   public static func ⊰(lhs: CGPoint, rhs: CGPoint) -> RedBlackTreeComparator {
      let (xl,yl,xr,yr) = (lhs.x,lhs.y,rhs.x,rhs.y)
      if yl > yr { return .leftTree }
      if yl == yr && xl < xr { return .leftTree }
      if yl == yr && xl == xr { return .matching }
      // For all other cases, i.e.
      // (lhs.y == rhs.y && lhs.x > rhs.x)
      // or lhs.y < rhs.y
      return .rightTree
   }
}

//MARK: - CGFloat

extension CGFloat: RedBlackTreeKeyProtocol {
   public static var duplicatesAllowed: Bool { return true }
   public static var duplicatesUseFIFO: Bool { return true }

   public static func ⊰(lhs: CGFloat, rhs: CGFloat) -> RedBlackTreeComparator {
      if lhs < rhs { return .leftTree }
      if lhs == rhs { return .matching }
      return .rightTree
   }
}
