//
//  Event.swift
//  Geometry
//
//  Created by Don McBrien on 25/05/2021.
//

import Foundation
import RedBlackTree

internal enum Event {
   case upper(LineSegment)
   case lower(LineSegment)
   case intersection(CGPoint,(LineSegment, LineSegment))
   
   func isIntersection() -> Bool {
      if case .intersection(_,_) = self { return true }
      return false
   }
}

extension Event: RedBlackTreeRecordProtocol {
   public var redBlackTreeKey: CGPoint {
      switch self {
         case .upper(let line): return CGPoint(x: line.upper.x, y: line.upper.y)
         case .lower(let line): return CGPoint(x: line.lower.x, y: line.lower.y)
         case .intersection(let point, _): return point
      }
   }
}

extension Event: CustomStringConvertible {
   var description: String {
      switch self {
         case let .upper(l): return "upper(\(l))"
         case let .lower(l): return "lower(\(l))"
         case let .intersection(p,s): return "intersection(\(p),\(s)"
      }
   }
}

