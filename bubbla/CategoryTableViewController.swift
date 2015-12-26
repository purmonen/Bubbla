import UIKit
import SafariServices

class CategoryTableViewController: UITableViewController, UISplitViewControllerDelegate {
    
    var categories = [(categoryType: String, categories: [String])]()
    
    static let recentString = "Senaste"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: "refresh:", forControlEvents: .ValueChanged)
        refresh()
        
        performSegueWithIdentifier("NewsSegue", sender: self)
        splitViewController?.maximumPrimaryColumnWidth = 350
        splitViewController?.delegate = self
    }
    
    func refresh(refreshControl: UIRefreshControl? = nil) {
        refreshControl?.beginRefreshing()
        BubblaApi.newsForCategory(nil) { response in
            NSOperationQueue.mainQueue().addOperationWithBlock {
                switch response {
                case .Success(let newsItems):
                    self.showEmptyMessage(false, message: "")
                    let categories = BubblaNews.categoriesWithTypesFromNewsItems(newsItems)
                    self.categories = [(categoryType: "", categories: [CategoryTableViewController.recentString])] + categories
                    self.tableView.reloadData()                    
                case .Error(let error):
                    if self.categories.isEmpty {
                        let errorMessage = (error as NSError).localizedDescription
                        self.showEmptyMessage(true, message: errorMessage)
                    } else {
                        print(error)
                    }
                }
                self.refreshControl?.endRefreshing()
            }
        }
    }
    
    func splitViewController(splitViewController: UISplitViewController, collapseSecondaryViewController secondaryViewController: UIViewController, ontoPrimaryViewController primaryViewController: UIViewController) -> Bool {
        if secondaryViewController is SFSafariViewController {
            return false
        }
        return true
    }
    
    func noNewsChosenViewController() -> UIViewController {
        return storyboard!.instantiateViewControllerWithIdentifier("NoNewsChosenViewController")
    }
    
    func splitViewController(splitViewController: UISplitViewController, separateSecondaryViewControllerFromPrimaryViewController primaryViewController: UIViewController) -> UIViewController? {
        if !(primaryViewController.childViewControllers.last is SFSafariViewController) {
            return noNewsChosenViewController()
        }
        return nil
    }
    
    override func viewWillAppear(animated: Bool) {
        deselectSelectedCell()
    }
    
    // MARK: - Table view data source
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return categories.count
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories[section].categories.count
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return categories[section].categoryType
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("CategoryTableViewCell", forIndexPath: indexPath) as! CategoryTableViewCell
        
        
        let category = categories[indexPath.section].categories[indexPath.row]
        cell.categoryLabel.text = category
        return cell
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let viewController = segue.destinationViewController as? NewsTableViewController {
            viewController.categoryTableViewController = self
            let category: String
            if let indexPath = tableView.indexPathForSelectedRow {
                category = categories[indexPath.section].categories[indexPath.row]
                tableView.deselectRowAtIndexPath(indexPath, animated: false)
            } else {
                category = _BubblaApi.selectedCategory ?? CategoryTableViewController.recentString
            }
            viewController.category = category
            _BubblaApi.selectedCategory = category
        }
        
        if let viewController = segue.destinationViewController as? PushNotificationsTableViewController {
            viewController.categories = Array(Set(categories.flatMap { $0.categories })).sort()
        }
    }
}

extension CategoryTableViewController: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(controller: SFSafariViewController) {
        let barButtonItem = splitViewController!.displayModeButtonItem()
        UIApplication.sharedApplication().sendAction(barButtonItem.action, to: barButtonItem.target, from: nil, forEvent: nil)
        
    }
}