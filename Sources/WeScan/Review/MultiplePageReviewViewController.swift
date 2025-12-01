//
//  MultiplePageReviewViewController.swift
//  WeScan
//
//  Created for multiple page scanning support.
//  Copyright © 2024 WeTransfer. All rights reserved.
//

import UIKit

/// The `MultiplePageReviewViewController` offers an interface to review, reorder, add, and delete multiple scanned pages.
final class MultiplePageReviewViewController: UIViewController {

    private var scannedPages: [ImageScannerResults]
    private let imageScannerController: ImageScannerController

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .black
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.dragInteractionEnabled = true
        collectionView.register(PageCollectionViewCell.self, forCellWithReuseIdentifier: "PageCell")
        return collectionView
    }()

    private lazy var doneButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(finishScanning))
        button.tintColor = navigationController?.navigationBar.tintColor
        return button
    }()

    private lazy var addPageButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addPage))
        button.tintColor = navigationController?.navigationBar.tintColor
        return button
    }()

    // MARK: - Life Cycle

    init(scannedPages: [ImageScannerResults], imageScannerController: ImageScannerController) {
        self.scannedPages = scannedPages
        self.imageScannerController = imageScannerController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Sync with accumulated pages
        imageScannerController.accumulatedPages = scannedPages

        setupViews()
        setupConstraints()
        setupNavigationBar()

        title = NSLocalizedString("wescan.multiple.review.title",
                                  tableName: nil,
                                  bundle: Bundle(for: MultiplePageReviewViewController.self),
                                  value: "Review Pages",
                                  comment: "The title of the MultiplePageReviewViewController"
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Update accumulated pages when leaving
        imageScannerController.accumulatedPages = scannedPages
    }

    // MARK: - Setups

    private func setupViews() {
        view.backgroundColor = .black
        view.addSubview(collectionView)
    }

    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = doneButton
        navigationItem.leftBarButtonItem = addPageButton
    }

    private func setupConstraints() {
        var collectionViewConstraints: [NSLayoutConstraint] = []
        if #available(iOS 11.0, *) {
            collectionViewConstraints = [
                view.safeAreaLayoutGuide.topAnchor.constraint(equalTo: collectionView.topAnchor),
                view.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: collectionView.trailingAnchor),
                view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: collectionView.bottomAnchor),
                view.safeAreaLayoutGuide.leadingAnchor.constraint(equalTo: collectionView.leadingAnchor)
            ]
        } else {
            collectionViewConstraints = [
                view.topAnchor.constraint(equalTo: collectionView.topAnchor),
                view.trailingAnchor.constraint(equalTo: collectionView.trailingAnchor),
                view.bottomAnchor.constraint(equalTo: collectionView.bottomAnchor),
                view.leadingAnchor.constraint(equalTo: collectionView.leadingAnchor)
            ]
        }

        NSLayoutConstraint.activate(collectionViewConstraints)
    }

    // MARK: - Actions

    @objc private func finishScanning() {
        imageScannerController.imageScannerDelegate?
            .imageScannerController(imageScannerController, didFinishScanningWithMultipleResults: scannedPages)
    }

    @objc private func addPage() {
        // Save current pages and navigate back to scanner to add another page
        imageScannerController.accumulatedPages = scannedPages
        imageScannerController.resetScanner()
    }

    func addMultiplePage(_ page: ImageScannerResults) {
        scannedPages.append(page)
        imageScannerController.accumulatedPages = scannedPages
        collectionView.reloadData()
    }
}

// MARK: - UICollectionViewDataSource

extension MultiplePageReviewViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return scannedPages.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PageCell", for: indexPath) as! PageCollectionViewCell
        let page = scannedPages[indexPath.item]
        let image = page.doesUserPreferEnhancedScan ? (page.enhancedScan?.image ?? page.croppedScan.image) : page.croppedScan.image
        cell.configure(with: image, pageNumber: indexPath.item + 1)
        cell.onDelete = { [weak self] in
            self?.deletePage(at: indexPath.item)
        }
        return cell
    }

    private func deletePage(at index: Int) {
        guard index < scannedPages.count else { return }
        scannedPages.remove(at: index)
        imageScannerController.accumulatedPages = scannedPages
        collectionView.reloadData()
    }
}

// MARK: - UICollectionViewDelegate

extension MultiplePageReviewViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Optionally allow editing individual pages
        let page = scannedPages[indexPath.item]
        let reviewVC = ReviewViewController(results: page)
        reviewVC.isFromMultiplePageFlow = true
        reviewVC.onPageUpdated = { [weak self] updatedPage in
            guard let self = self else { return }
            self.scannedPages[indexPath.item] = updatedPage
            self.imageScannerController.accumulatedPages = self.scannedPages
            self.collectionView.reloadData()
        }
        navigationController?.pushViewController(reviewVC, animated: true)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension MultiplePageReviewViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width - 48) / 2 // 2 columns with spacing
        let aspectRatio: CGFloat = 8.5 / 11.0 // Standard document aspect ratio
        return CGSize(width: width, height: width / aspectRatio)
    }
}

// MARK: - UICollectionViewDragDelegate

extension MultiplePageReviewViewController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let item = scannedPages[indexPath.item]
        let itemProvider = NSItemProvider(object: "\(indexPath.item)" as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = item
        return [dragItem]
    }
}

// MARK: - UICollectionViewDropDelegate

extension MultiplePageReviewViewController: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        return session.localDragSession != nil
    }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let destinationIndexPath = coordinator.destinationIndexPath,
              let dragItem = coordinator.items.first,
              let sourceIndexPath = dragItem.sourceIndexPath,
              sourceIndexPath != destinationIndexPath,
              let item = dragItem.dragItem.localObject as? ImageScannerResults else {
            return
        }

        let sourceIndex = sourceIndexPath.item
        let destinationIndex = destinationIndexPath.item

        // Update data source first
        scannedPages.remove(at: sourceIndex)
        let insertIndex = destinationIndex > sourceIndex ? destinationIndex - 1 : destinationIndex
        scannedPages.insert(item, at: insertIndex)
        imageScannerController.accumulatedPages = scannedPages

        collectionView.performBatchUpdates({
            // Use moveItem for better index handling
            collectionView.moveItem(at: sourceIndexPath, to: IndexPath(item: insertIndex, section: 0))
        }, completion: { [weak self] _ in
            // Reload all visible cells to update page numbers after reordering
            guard let self = self else { return }
            let visibleIndexPaths = self.collectionView.indexPathsForVisibleItems
            self.collectionView.reloadItems(at: visibleIndexPaths)
        })

        coordinator.drop(dragItem.dragItem, toItemAt: destinationIndexPath)
    }
}

// MARK: - PageCollectionViewCell

private class PageCollectionViewCell: UICollectionViewCell {
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .white
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let pageNumberLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let deleteButton: UIButton = {
        let button = UIButton(type: .system)
        let image = UIImage(systemName: "xmark.circle.fill", compatibleWith: nil)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.red.withAlphaComponent(0.8)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    var onDelete: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.backgroundColor = .clear
        contentView.addSubview(imageView)
        contentView.addSubview(pageNumberLabel)
        contentView.addSubview(deleteButton)

        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            pageNumberLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            pageNumberLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            pageNumberLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 30),
            pageNumberLabel.heightAnchor.constraint(equalToConstant: 24),

            deleteButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            deleteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            deleteButton.widthAnchor.constraint(equalToConstant: 24),
            deleteButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    func configure(with image: UIImage, pageNumber: Int) {
        imageView.image = image
        pageNumberLabel.text = "\(pageNumber)"
    }

    @objc private func deleteTapped() {
        onDelete?()
    }
}

