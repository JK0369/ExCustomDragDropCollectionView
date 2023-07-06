//
//  ViewController.swift
//  ExDragDropCollectionView
//
//  Created by 김종권 on 2023/07/06.
//

import UIKit

final class MyCell: UICollectionViewCell {
    override init(frame: CGRect) {
        super.init(frame: .zero)
        contentView.backgroundColor = [UIColor.black, .blue, .orange, .yellow].randomElement()
    }
    required init?(coder: NSCoder) {
        fatalError()
    }
}

class ViewController: UIViewController {
    private enum Const {
        static let cellLength = 120.0
    }
    
    private let dragDropCollectionView: DragDropCollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = .init(width: Const.cellLength, height: Const.cellLength)
        let view = DragDropCollectionView(frame: .zero, collectionViewLayout: layout)
        layout.scrollDirection = .horizontal
        
        view.register(MyCell.self, forCellWithReuseIdentifier: "cell")
        view.translatesAutoresizingMaskIntoConstraints = false
        view.enableDragging(true)
        return view
    }()
    private let textField: UITextField = {
        let field = UITextField()
        field.placeholder = "input text.."
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()
    
    var dataSource = (1...10).map(String.init)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(textField)
        view.addSubview(dragDropCollectionView)
        
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
        ])
        
        NSLayoutConstraint.activate([
            dragDropCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dragDropCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dragDropCollectionView.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 20),
            dragDropCollectionView.heightAnchor.constraint(equalToConstant: Const.cellLength),
        ])
        
        dragDropCollectionView.dataSource = self
        dragDropCollectionView.dragDropDelegate = self
    }
}

extension ViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        dataSource.count
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! MyCell
        return cell
    }
}

extension ViewController: DragDropCollectionViewDelegate {
    func didMoveCell(sourceIndexPath: IndexPath, destinationIndexPath: IndexPath) {
//        let sourceItem = dataSource[sourceIndexPath.item]
//        
//        dataSource.remove(at: sourceIndexPath.item)
//        dataSource.insert(sourceItem, at: destinationIndexPath.item)
//        
//        dragDropCollectionView.deleteItems(at: [sourceIndexPath])
//        dragDropCollectionView.insertItems(at: [destinationIndexPath])
    }
    
    func draggingDidBegin(indexPath: IndexPath) {
        print("draggingDidBegin>", indexPath.row)
    }
    
    func draggingDidEnd(indexPath: IndexPath) {
        print("draggingDidEnd>", indexPath.row)
    }
}
