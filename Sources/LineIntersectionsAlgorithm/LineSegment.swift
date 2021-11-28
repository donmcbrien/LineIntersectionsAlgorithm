//
//  LineSegment.swift
//  Geometry
//
//  Created by Don McBrien on 26/05/2021.
//

import Foundation
import RedBlackTree

//MARK: - LineSegmentProtocol
public protocol LineSegmentProtocol {
   var from: CGPoint { get }
   var to: CGPoint { get }
}

//MARK: - LineSegment
// I'm using a class rather than a struct because I want to give the algorithm
// access to `intersectionPoint` by reference at steps 3 and 8
class LineSegment {
   static var eventPoint = CGPoint(x:0,y:0)  // the point the line intersection algorithm is working on

   var index: Int       // index into array provided by the user
   var upper: CGPoint
   var lower: CGPoint
   
   var i: CGFloat { lower.x - upper.x }
   var j: CGFloat { lower.y - upper.y }
   
   var isVertical: Bool { upper.x == lower.x ? true : false }
   var isHorizontal: Bool { upper.y == lower.y ? true : false }
   
   init(index: Int, from: CGPoint, to: CGPoint) {
      self.index = index
      (upper, lower) =  from < to ? (from, to) : (to, from)
   }

   var intersectionPoint: CGPoint?
   var sweeplinePosition: CGPoint {
      // only called for segments on the sweepline
      // the x value on the line segment when y = LineSegment.sweepLine
      if let ip = intersectionPoint { return ip }
      if isHorizontal { return LineSegment.eventPoint }
      let x = (((LineSegment.eventPoint.y - upper.y) * i / j) + upper.x)
      return CGPoint(x: x, y: LineSegment.eventPoint.y)
   }
   
   var rotatedSlope: CGFloat? {
      // used to sort points at an intersection such that they read left to right on
      // the status line at a position infinitesimally below the sweepline position
      if isHorizontal { return nil }  // vertical line
      return -(i / j)
   }

   func intersection(with ls: LineSegment) -> CGPoint? {
      let parallelTest = (ls.j * i) - (ls.i * j)
      guard parallelTest != 0.0 else { return nil } // parallel or overlapping
      
      let s = (i * (upper.y - ls.upper.y) + j * (ls.upper.x - upper.x)) / parallelTest
      if s < 0.0 || s > 1.0 { return nil }  // intersects beyond segments

      let t = (ls.i * (upper.y - ls.upper.y) + ls.j * (ls.upper.x - upper.x)) / parallelTest
      if t < 0.0 || t > 1.0 { return nil }  // intersects beyond segments

      //TODO: inelegant max of almost equal funcs to avoid rounding error
      return CGPoint(x: max(CGFloat(upper.x + t * i), CGFloat(ls.upper.x + s * ls.i)),
                     y: max(CGFloat(upper.y + t * j), CGFloat(ls.upper.y + s * ls.j)))
   }

   private func overlaps(with ls: LineSegment) -> Bool {
      guard (ls.i * j) == (ls.j * i) else { return false }
      return max(ls.upper, self.upper) < min(ls.lower, self.lower)
   }

   static func overlapOrder(_ lhs: LineSegment, _ rhs: LineSegment) -> (retain: LineSegment, suspend: LineSegment)? {
      // returns the line segment in an overlapping pair which
      // will remain longest under the sweepline
      // or nil if no overlap
      guard lhs != rhs else { return nil }
      guard lhs.overlaps(with: rhs) else { return nil }
      if lhs.lower < rhs.lower { return (rhs,lhs) }
      return (lhs, rhs)
   }
}

//MARK: - LineSegment protocol conformance
extension LineSegment: RedBlackTreeRecordProtocol {
   public var redBlackTreeKey: CGFloat { return sweeplinePosition.x }
}

extension LineSegment: Equatable, Hashable {
   func hash(into hasher: inout Hasher) {
      hasher.combine(upper)
      hasher.combine(lower)
   }
   
   static func == (lhs: LineSegment, rhs: LineSegment) -> Bool {
      return lhs.upper == rhs.upper && lhs.lower == rhs.lower
   }
}

extension LineSegment: CustomStringConvertible{
   var description: String { return " LS:\(index) \(upper) \(lower)" }
}

