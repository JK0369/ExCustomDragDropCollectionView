//
//  DragDropCollectionView.swift
//  ExDragDropCollectionView
//
//  Created by 김종권 on 2023/07/06.
//

import UIKit

// MARK: - Constant

private enum Policy {
    static let minimumPressDuration = 0.5
    static let allowableMovement = 10.0
    static let pingInterval = 0.03
}


// MARK: - Delegate

protocol DragDropCollectionViewDelegate: AnyObject {
    func didMoveCell(sourceIndexPath: IndexPath, destinationIndexPath: IndexPath)
    func draggingDidBegin(indexPath: IndexPath)
    func draggingDidEnd(indexPath: IndexPath)
}


// MARK: - DragDropCollectionView

final class DragDropCollectionView: UICollectionView {
    // MARK: UI
    private var draggingView: UIView?
    
    // MARK: Property
    weak var dragDropDelegate: DragDropCollectionViewDelegate?
    private let longPressRecognizer: UILongPressGestureRecognizer = {
        let recognizer = UILongPressGestureRecognizer()
        /// 롱 프레스 중 다른 터치가 발생했을때 해당 제스쳐를 취소할것인지 유무 (false로 하여 취소되지 않도록 설정)
        recognizer.cancelsTouchesInView = false
        recognizer.minimumPressDuration = Policy.minimumPressDuration
        recognizer.allowableMovement = Policy.allowableMovement
        return recognizer
    }()
    private var draggedCellIndexPath: IndexPath?
    private var touchOffsetFromCenterOfCell: CGPoint?
    private var isAutoScrolling = false
    
    // MARK: Initializer
    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        addLongPressGesture()
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("\(#function) not implemented")
    }
    
    // MARK: Method
    func enableDragging(_ enable: Bool) {
        longPressRecognizer.isEnabled = enable
    }
}


// MARK: - Private Method

private extension DragDropCollectionView {
    func addLongPressGesture() {
        longPressRecognizer.addTarget(self, action: #selector(handleLongPress(_:)))
        longPressRecognizer.isEnabled = false
        addGestureRecognizer(longPressRecognizer)
    }
    
    @objc func handleLongPress(_ longPressRecognizer: UILongPressGestureRecognizer) {
        let touchLocation = longPressRecognizer.location(in: self)
        
        switch longPressRecognizer.state {
        case .began:
            handleBegan(touchLocation: touchLocation)
        case .changed:
            handleChanged(touchLocation: touchLocation)
        case .ended:
            handleEnded(touchLocation: touchLocation)
        default:
            break
        }
    }
    
    func handleBegan(touchLocation: CGPoint) {
        draggedCellIndexPath = indexPathForItem(at: touchLocation)
        guard
            let draggedCellIndexPath = draggedCellIndexPath,
            let draggedCell = cellForItem(at: draggedCellIndexPath)
        else { return }
        
        dragDropDelegate?.draggingDidBegin(indexPath: draggedCellIndexPath)
        let draggingView = UIImageView(image: getRasterizedImageCopyOfCell(draggedCell))
        self.draggingView = draggingView
        draggingView.center = (draggedCell.center)
        addSubview(draggingView)
        draggedCell.isHidden = true
        
        touchOffsetFromCenterOfCell = CGPoint(x: draggedCell.center.x - touchLocation.x, y: draggedCell.center.y - touchLocation.y)
        UIView.animate(
            withDuration: 0.4,
            animations: {
                draggingView.transform = .init(scaleX: 1.1, y: 1.1)
                draggingView.alpha = 0.9
                draggingView.layer.shadowRadius = 20
                draggingView.layer.shadowColor = UIColor.lightGray.cgColor
                draggingView.layer.shadowOpacity = 0.2
                draggingView.layer.shadowOffset = CGSize(width: 0, height: 25)
            }
        )
    }
    
    func handleChanged(touchLocation: CGPoint) {
        if !isAutoScrolling {
            dispatchOnMainQueueAfter(Policy.pingInterval, closure: { () -> () in
                let scroller = self.shouldAutoScroll(touchLocation)
                if scroller.shouldScroll {
                    self.autoScroll(scroller.direction)
                    self.isAutoScrolling = true
                }
            })
        }
        
        guard
            draggedCellIndexPath != nil,
            let touchOffsetFromCenterOfCell = touchOffsetFromCenterOfCell
        else { return }
        
        draggingView?.center = CGPoint(
            x: touchLocation.x + touchOffsetFromCenterOfCell.x,
            y: touchLocation.y + touchOffsetFromCenterOfCell.y
        )
        
        dispatchOnMainQueueAfter(
            Policy.pingInterval,
            closure: {
                let shouldSwapCellsTuple = self.shouldSwapCells(touchLocation)
                if shouldSwapCellsTuple.shouldSwap {
                    guard let newIndexPath = shouldSwapCellsTuple.newIndexPath else { return }
                    self.swapDraggedCellWithCellAtIndexPath(newIndexPath)
                }
            }
        )
    }
    
    func handleEnded(touchLocation: CGPoint) {
        guard
            let draggedCellIndexPath = draggedCellIndexPath,
            let draggedCell = cellForItem(at: draggedCellIndexPath)
        else { return }
        
        dragDropDelegate?.draggingDidEnd(indexPath: draggedCellIndexPath)
        
        UIView.animate(
            withDuration: 0.4,
            animations: {
                self.draggingView?.transform = .identity
                self.draggingView?.alpha = 1.0
                self.draggingView?.center = draggedCell.center
                self.draggingView?.layer.shadowRadius = 0
                self.draggingView?.layer.shadowColor = nil
                self.draggingView?.layer.shadowOffset = .zero
            },
            completion: { finished -> Void in
                self.draggingView?.removeFromSuperview()
                self.draggingView = nil
                draggedCell.isHidden = false
                self.draggedCellIndexPath = nil
            }
        )
    }
    
    func shouldSwapCells(_ previousTouchLocation: CGPoint) -> (shouldSwap: Bool, newIndexPath: IndexPath?) {
        guard
            case let currentTouchLocation = longPressRecognizer.location(in: self),
            let draggedCellIndexPath = draggedCellIndexPath,
            !Double(currentTouchLocation.x).isNaN,
            !Double(currentTouchLocation.y).isNaN,
            distanceBetweenPoints(previousTouchLocation, secondPoint: currentTouchLocation) < CGFloat(20.0),
            let newIndexPathForCell = indexPathForItem(at: currentTouchLocation),
            newIndexPathForCell != draggedCellIndexPath
        else { return (false, nil) }
        
        return (true, newIndexPathForCell)
    }
    
    func swapDraggedCellWithCellAtIndexPath(_ newIndexPath: IndexPath) {
        guard let draggedCellIndexPath = draggedCellIndexPath else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        moveItem(at: draggedCellIndexPath, to: newIndexPath)
        dragDropDelegate?.didMoveCell(sourceIndexPath: draggedCellIndexPath, destinationIndexPath: newIndexPath)
        self.draggedCellIndexPath = newIndexPath
    }
}


// MARK: - Helper Method

private extension DragDropCollectionView {
    func getRasterizedImageCopyOfCell(_ cell: UICollectionViewCell) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(cell.bounds.size, false, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        cell.layer.render(in: context)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    func dispatchOnMainQueueAfter(_ delay: Double, closure: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay,
            qos: .userInteractive,
            flags: .enforceQoS,
            execute: closure
        )
    }
    
    func distanceBetweenPoints(_ firstPoint: CGPoint, secondPoint: CGPoint) -> CGFloat {
        let xDistance = firstPoint.x - secondPoint.x
        let yDistance = firstPoint.y - secondPoint.y
        return sqrt(xDistance * xDistance + yDistance * yDistance)
    }
}

//AutoScroll
extension DragDropCollectionView {
    enum AutoScrollDirection: Int {
        case invalid = 0
        case towardsOrigin = 1
        case awayFromOrigin = 2
    }
    
    func autoScroll(_ direction: AutoScrollDirection) {
        let currentLongPressTouchLocation = self.longPressRecognizer.location(in: self)
        var increment: CGFloat
        var newContentOffset: CGPoint
        if (direction == AutoScrollDirection.towardsOrigin) {
            increment = -50.0
        } else {
            increment = 50.0
        }
        newContentOffset = CGPoint(x: self.contentOffset.x, y: self.contentOffset.y + increment)
        let flowLayout = self.collectionViewLayout as! UICollectionViewFlowLayout
        if flowLayout.scrollDirection == UICollectionView.ScrollDirection.horizontal{
            newContentOffset = CGPoint(x: self.contentOffset.x + increment, y: self.contentOffset.y)
        }
        if ((direction == AutoScrollDirection.towardsOrigin && newContentOffset.y < 0) || (direction == AutoScrollDirection.awayFromOrigin && newContentOffset.y > self.contentSize.height - self.frame.height)) {
            dispatchOnMainQueueAfter(0.3, closure: { () -> () in
                self.isAutoScrolling = false
            })
        } else {
            UIView.animate(withDuration: 0.3
                           , delay: 0.0
                           , options: UIView.AnimationOptions.curveLinear
                           , animations: { () -> Void in
                self.setContentOffset(newContentOffset, animated: false)
                if (self.draggingView != nil) {
                    if flowLayout.scrollDirection == UICollectionView.ScrollDirection.vertical{
                        var draggingFrame = self.draggingView!.frame
                        draggingFrame.origin.y += increment
                        self.draggingView!.frame = draggingFrame
                    }else{
                        var draggingFrame = self.draggingView!.frame
                        draggingFrame.origin.x += increment
                        self.draggingView!.frame = draggingFrame
                    }
                }
            }) { (finished) -> Void in
                self.dispatchOnMainQueueAfter(0.0, closure: { () -> () in
                    var updatedTouchLocationWithNewOffset = CGPoint(x: currentLongPressTouchLocation.x, y: currentLongPressTouchLocation.y + increment)
                    if flowLayout.scrollDirection == UICollectionView.ScrollDirection.horizontal{
                        updatedTouchLocationWithNewOffset = CGPoint(x: currentLongPressTouchLocation.x + increment, y: currentLongPressTouchLocation.y)
                    }
                    let scroller = self.shouldAutoScroll(updatedTouchLocationWithNewOffset)
                    if scroller.shouldScroll {
                        self.autoScroll(scroller.direction)
                    } else {
                        self.isAutoScrolling = false
                    }
                })
            }
        }
    }
    
    func shouldAutoScroll(_ previousTouchLocation: CGPoint) -> (shouldScroll: Bool, direction: AutoScrollDirection) {
        let previousTouchLocation = self.convert(previousTouchLocation, to: self.superview)
        let currentTouchLocation = self.longPressRecognizer.location(in: self.superview)
        
        if let flowLayout = self.collectionViewLayout as? UICollectionViewFlowLayout {
            if !Double(currentTouchLocation.x).isNaN && !Double(currentTouchLocation.y).isNaN {
                if distanceBetweenPoints(previousTouchLocation, secondPoint: currentTouchLocation) < CGFloat(20.0) {
                    let scrollBoundsLength: CGFloat = 50.0
                    let scrollBoundsSize = CGSize(width: scrollBoundsLength, height: self.frame.height)
                    let scrollRectAtEnd = CGRect(x: self.frame.origin.x + self.frame.width - scrollBoundsSize.width , y: self.frame.origin.y, width: scrollBoundsSize.width, height: self.frame.height)
                    
                    let scrollRectAtOrigin = CGRect(origin: self.frame.origin, size: scrollBoundsSize)
                    
                    if scrollRectAtOrigin.contains(currentTouchLocation) {
                        return (true, .towardsOrigin)
                    } else if scrollRectAtEnd.contains(currentTouchLocation) {
                        return (true, .awayFromOrigin)
                    }
                }
            }
        }
        return (false, AutoScrollDirection.invalid)
    }
}
