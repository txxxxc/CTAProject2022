//
//  SearchShopsViewController.swift
//  CTAProject
//
//  Created by Tomoya Tanaka on 2022/01/12.
//

import Moya
import PKHUD
import RxCocoa
import RxDataSources
import RxSwift
import SnapKit
import UIKit

final class SearchShopsViewController: UIViewController {

    private let disposeBag = DisposeBag()
    private let viewModel: SearchShopsViewModelType

    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .systemGray6
        tableView.rowHeight = Const.TableViewCell.height
        tableView.register(SearchShopsTableViewCell.self, forCellReuseIdentifier: SearchShopsTableViewCell.reuseIdentifier)
        return tableView
    }()

    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = L10n.searchShopsSearchBarPlaceholder
        return searchBar
    }()

    init(viewModel: SearchShopsViewModelType) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()

        searchBar.rx.searchButtonClicked
            .subscribe(onNext: { [searchBar] _ in
                searchBar.resignFirstResponder()
                searchBar.endEditing(true)
            })
            .disposed(by: disposeBag)

        let searchBarText = searchBar.rx.textDidEndEditing
            .withLatestFrom(searchBar.rx.text.orEmpty)
            .distinctUntilChanged()
            .asDriver(onErrorJustReturn: "")

        searchBarText
            .asObservable()
            .map { _ in "" }
            .bind(to: searchBar.rx.text)
            .disposed(by: disposeBag)

        searchBarText
            .drive(onNext: { [weak self] text in
                guard let self = self else { return }
                self.viewModel.inputs.searchWord.onNext(text)
            })
            .disposed(by: disposeBag)

        let dataSource = initializeDataSource()

        viewModel.outputs.shops
            .asObservable()
            .map { items in
                let sections = [SearchShopsTableViewSection(items: items)]
                return sections
            }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        viewModel.outputs.loading
            .drive(onNext: { isProgress in
                isProgress ? HUD.show(.progress) : HUD.hide()
            })
            .disposed(by: disposeBag)

        viewModel.outputs.hasSearchWordCountExceededError
            .drive(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.view.addSubview(SearchShopsAlertModal())
            })
            .disposed(by: disposeBag)

    }
    // NOTE: navigationBarを参照する必要があるので、viewDidAppearでAutoLayoutの設定を呼んでいます
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        makeConstraints()
    }

    private func initializeDataSource() -> RxTableViewSectionedReloadDataSource<SearchShopsTableViewSection> {
        return RxTableViewSectionedReloadDataSource<SearchShopsTableViewSection>(
            configureCell: { [viewModel] dataSource, tableView, indexPath, item in
                let cell = tableView.dequeueReusableCell(withIdentifier: SearchShopsTableViewCell.reuseIdentifier, for: indexPath)

                guard let cell = cell as? SearchShopsTableViewCell else {
                    fatalError("SearchShopsTableViewCell is not configured properly")
                }

                Observable.just(item)
                    .bind(to: cell.rx.bindCellData)
                    .disposed(by: cell.disposeBag)

                cell.didTapFavoriteButton
                    .asObservable()
                    .flatMap { _ -> Observable<IndexPath> in
                        return Observable.just(indexPath)
                    }
                    .bind(to: viewModel.inputs.tapFavoriteButton)
                    .disposed(by: cell.disposeBag)

                return cell

            }
        )
    }

}

// MARK: Constants
extension SearchShopsViewController {
    enum Const {
        enum SearchBar {
            static let height = 64
            static let maxWordCount = 50
        }

        enum TableViewCell {
            static let height: CGFloat = 192
        }
    }
}

// MARK: UI Configuration
extension SearchShopsViewController {
    private func setupView() {
        view.backgroundColor = .white
        view.addSubview(tableView)
        view.addSubview(searchBar)
        navigationItem.title = L10n.searchShopsNavigationBarTitle
    }

}

// MARK: AutoLayout Configuration
extension SearchShopsViewController {
    private func makeConstraints() {
        searchBar.snp.makeConstraints { make in
            make.width.equalTo(view)
            make.height.equalTo(Const.SearchBar.height)
            if let navigationBar = navigationController?.navigationBar {
                make.top.equalTo(navigationBar.snp.bottom)
            } else {
                make.top.equalTo(view.snp.top)
            }
        }
        tableView.snp.makeConstraints { make in
            make.width.equalTo(view)
            make.top.equalTo(searchBar.snp.bottom)
            make.bottom.equalTo(view.snp.bottom)
            make.leading.equalTo(view.snp.leading)
            make.trailing.equalTo(view.snp.trailing)
        }
    }
}
