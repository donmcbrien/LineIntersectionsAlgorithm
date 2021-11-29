import Foundation
import RedBlackTree

//MARK: - LineIntersectionAlgorithm
public struct LineIntersectionAlgorithm {
   //Model Outputs
   /// A boolean variable which reports if all events in the EventQueue have been processed.
   /// Useful when stepping throug the model.
   public var isProcessingCompleted: Bool { return eventQueue.count == 0 }

   /// Provides an array of tuples each consisting of an intersection point and an array of indices pointing to
   /// those line segments in the input which give rise to that intersection. Check `isProcessingCompleted`
   /// to ensure all solutions are included.
   public var intersectionsXReference: [(point: CGPoint, lineSegmentIndices: [Int])] {
      return intersectionsDictionary.map { ($0.key,($0.value.map { $0.index })) }
   }
   
   /// Provides an array of `CGPoint`s where line segments cleanly intersect (i.e. intersect but do not overlap).
   /// Check `isProcessingCompleted` to ensure all solutions are included.
   public var intersections: [CGPoint] {
      return intersectionsDictionary.map { $0.key }
   }

   /// Provides an array tuples, each containing the extremities of that part of two line segments which overlap.
   /// A separate tuple is produced for each overlap when more than two overlaps are stacked. Check
   /// `isProcessingCompleted` to ensure all solutions are included.
   public var overlaps: [(upper: CGPoint, lower: CGPoint)] { overlappingSegments.map { $0.overlap } }

   /// Provides an array of tuples, each combining a tuple from `overlaps` and a second tuple containing indices
   /// pointing to the pair of line segments which give rise to that overlap. Check `isProcessingCompleted`
   /// to ensure all solutions are included.
   public var overlapsXReference: [(overlap: (CGPoint, CGPoint), indices: (Int, Int))] {
      overlappingSegments.map { ($0.overlap, ($0.retain.index, $0.suspend.index)) }
   }

   private var suspendedSegments = Set<LineSegment>()
   private var overlappingSegments = Set<Overlap>()
   private var intersectionsDictionary = [CGPoint : [LineSegment]]()

   private var eventQueue = RedBlackTree<Event, CGPoint>()
   private var statusLine = RedBlackTree<LineSegment, CGFloat>()
   
   public init(lineSegments: [LineSegmentProtocol]) {
      for i in 0..<lineSegments.count {
         let ls = LineSegment(index: i,
                              from: lineSegments[i].from,
                              to: lineSegments[i].to)
         eventQueue.insert(Event.upper(ls))
         eventQueue.insert(Event.lower(ls))
      }
   }
}

//MARK: - Algorithm
extension LineIntersectionAlgorithm {
   /// Handles all the events at the next unprocessed event point.
   ///
   /// - Returns: void
   public mutating func processNextEventPoint() {
      return handleEventsAtNextEventPoint()
   }

   /// Handles all unprocessed events in order.
   ///
   /// - Returns: void
   public mutating func processAllRemainingEvents() {
      while eventQueue.count > 0 { handleEventsAtNextEventPoint() }
   }

   /// Handles all the events at a single event point, mutating all output variables if  intersections or overlaps arise.
   ///
   /// - Returns: void
   private mutating func handleEventsAtNextEventPoint() {
      // 1. Check that the eventQueue is not empty; get the event.
      guard let event = eventQueue.first else { return }

      // 2. Move the sweepline to it and obtain all events which have this point as key
      LineSegment.eventPoint = event.redBlackTreeKey
      let events = eventQueue.removeAll(LineSegment.eventPoint)

      // 3. Prepare three sets and partition events into the sets
      //    ● new uppers from these events (to be added as intersectors with others
      //      traversing the eventPoint (i.e. lines in events) and added to the statusLine)
      //    ● new lowers (to be removed from the statusLine and suspendedSegments)
      //    ● intersectors (to set the intersection point precisely on the sweepline)
      var uppers = Set<LineSegment>()
      var lowers = Set<LineSegment>()
      var intersectors = Set<LineSegment>()

      for e in events {
         switch e {
            case let .upper(segment): uppers.insert(segment)
            case let .lower(segment): lowers.insert(segment)
            case let .intersection(_, segment):
               intersectors.insert(segment.0)
               intersectors.insert(segment.1)
         }
      }

      // 4. Set the intersectionPoint on intersectors (for precision reasons) and
      //    remove segments traversing the eventPoint from the statusLine.
      intersectors.forEach { $0.intersectionPoint = LineSegment.eventPoint }
      statusLine.removeAll(LineSegment.eventPoint.x)

      // 5. Record new intersections at eventPoint
      if uppers.count > 0 {
         let union = uppers.union(lowers).union(intersectors)
         if union.count > 1 {
            uppers.forEach { upper in
               union.forEach { if $0 != upper {recordIntersection(point: LineSegment.eventPoint, segments: ($0,upper))}}
            }
         }
      }

      // 6. Remove any departing lowers from suspendedSegments and handle overlaps.
      //    Check if any uppers overlap any intersectors or other uppers. 'remain' is
      //    the line segment whose 'lower' descends further (i.e will remain longer
      //    on the status line). Remove 'leave' and report it.
      //    Do this before 6. because overlaps are NOT intersections.

      suspendedSegments.subtract(lowers)
      for upper in uppers {
         var overlapCandidates = uppers.union(intersectors)
         overlapCandidates.remove(upper)
         for segment in overlapCandidates {
            // identify and note new overlaps among them
            if let (retain, suspend) = LineSegment.overlapOrder(upper, segment) {
               intersectors.remove(suspend)
               uppers.remove(suspend)
               suspendedSegments.insert(suspend)
               overlappingSegments.insert(Overlap(retain:retain, suspend:suspend))
               // if upper is in overlap, check for overlap with suspendedSegments too
               for seg in suspendedSegments {
                  if let (retain, suspend) = LineSegment.overlapOrder(upper, seg) {
                     overlappingSegments.insert(Overlap(retain:retain, suspend:suspend))
                  }
               }
            }
         }
      }

      // 7. Reinsert all except lowers, sorted by rotated slope,
      //    placing horizontal segments last.
      //    (The closure takes some figuring out: a rotated horizontal
      //     slope is vertical and therefore nil and we want it last
      //     in the sort).
      let reinserts = Array(uppers.union(intersectors).subtracting(lowers)).sorted {
         if $0.rotatedSlope == nil { return false }
         else {
            if ($1.rotatedSlope == nil) { return true }
            else { return ($0.rotatedSlope!) < ($1.rotatedSlope!) }
         }
      }
      reinserts.forEach { statusLine.insert($0) }

      // 8. Check for intersections between new neighbours on the status line
      //    a) if nothing to insert, items on either side of the event need checking
      //    b) otherwise the left end needs checking with the left neighbour and
      //       the right end with the right neighbour.
      //    Of course there are no new intersections inside reinserts since
      //    they have already intersected.
      if reinserts.count == 0 {
         let (left, right) = statusLine.neighboursFor(LineSegment.eventPoint.x)
         if let l = left,
            let r = right  {
            addIntersectionEvent(left: l, right: r, beyond: LineSegment.eventPoint)
         }
      } else {
         let r = reinserts.first!
         let (left, _) = statusLine.neighboursOf(r.redBlackTreeKey)!
         if let l = left {
            addIntersectionEvent(left: l, right: r, beyond: LineSegment.eventPoint)
         }
         let l = reinserts.last!
         let (_, right) = statusLine.neighboursOf(l.redBlackTreeKey)!
         if let r = right  {
            addIntersectionEvent(left: l, right: r, beyond: LineSegment.eventPoint)
         }
      }
      
      // 9. Clear forced intersectionPoint
      intersectors.forEach { $0.intersectionPoint = nil }

      return
   }
}

//MARK: - Helpers
extension LineIntersectionAlgorithm {
   private mutating func recordIntersection(point: CGPoint, segments: (LineSegment,LineSegment)) {
      if let oldValue = intersectionsDictionary[point] {
         intersectionsDictionary[point] = Array(Set(oldValue + [segments.0,segments.1]))
      } else {
         intersectionsDictionary[point] = [segments.0,segments.1]
      }
   }

   /// Adds an .intersection event to the eventQueue if the line segments intersect
   /// beyond the current event point.
   ///
   /// When adding an intersection event, it should be joined to any already
   /// existing intersection events at the same point.
   /// - Parameter left: A line segment
   /// - Parameter right: A second line segment
   /// - Parameter beyond: The current event point
   /// - Returns: `Void`. `eventQueue` will be mutated if there is an intersection
   private mutating func addIntersectionEvent(left: LineSegment, right: LineSegment, beyond: CGPoint) {
      guard let pt = left.intersection(with: right) else { return }
      guard pt.y <= LineSegment.eventPoint.y else { return }
      if pt.y == LineSegment.eventPoint.y { guard pt.x > beyond.x else { return } }
      eventQueue.insert(Event.intersection(pt, (left, right)))
      recordIntersection(point: pt, segments: (left,right))
   }
}

//MARK: - Overlap
private struct Overlap: Equatable, Hashable {
   var retain: LineSegment
   var suspend: LineSegment
   var overlap: (CGPoint, CGPoint) { (max(retain.upper, suspend.upper), min(retain.lower, suspend.lower)) }

   func hash(into hasher: inout Hasher) {
      hasher.combine(retain)
      hasher.combine(suspend)
   }

   static func == (lhs: Overlap, rhs: Overlap) -> Bool {
      return lhs.retain == rhs.retain && lhs.suspend == rhs.suspend
   }
}


/*  For Later
 //MARK: - LineIntersectionsAlgorithm
 public class LineIntersectionsAlgorithm {
    public var intersectionCalls: Int { LineSegment.intersectionCalls }
 
 
    var naiveSegments = [LineSegment]()
    var naiveIntersections = [(CGPoint,(Int,Int))]()
    func naive() {
       let start = Date()
       print("Start ",start)
       for m in 0..<naiveSegments.count {
          for n in (m+1)..<naiveSegments.count {
             if let intersec = naiveSegments[m].intersection(with: naiveSegments[n]) { naiveIntersections.append((intersec,(naiveSegments[m].index,naiveSegments[n].index))) }
          }
       }
       let duration = Date().timeIntervalSince(start)
       print("Duration ",duration)
       print("Calls: ",LineSegment.intersectionCalls, naiveIntersections.count)
       print()
       for inter in naiveIntersections.sorted(by: { $0.0 < $1.0 && $0.1 > $1.1 }) {
          print("\(inter.0),\(inter.1)")
       }
    }
 }
 
 //MARK: - Private Methods
 extension LineIntersectionsAlgorithm {

    func recoverHiddenIntersections() {
       // make dict of ls which overlap each other
       var dict = [LineSegment: [LineSegment]]()
       for ol in overlappingSegments {
          if let oldValue = dict[ol.remain] {
             dict[ol.remain] = oldValue + [ol.leave]
          } else {
             dict[ol.remain] = [ol.leave]
          }
          if let oldValue = dict[ol.leave] {
             dict[ol.leave] = oldValue + [ol.remain]
          } else {
             dict[ol.leave] = [ol.remain]
          }
       }
 
       // make every line with an intersection propagate to its overlappers
       for (pt,lines) in intersectionsDictionary {
          for ls in lines {
             if let overs = dict[ls] {
                for ol in overs {
                   if ol.shares(y: pt.y, with: ls) {
                      intersectionsDictionary[pt] = intersectionsDictionary[pt]! + [ol]
                   }
                }
             }
          }
       }
    }
 }
 
*/
