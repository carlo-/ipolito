//
//  GradesViewController.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 30/07/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit


class CareerViewController: UITableViewController {

    var temporaryGrades: [PTTemporaryGrade] = [] {
        didSet {
            tableView.reloadData()
        }
    }
    var passedExams: [PTExam] = [] {
        didSet {
            tableView.reloadData()
        }
    }
    var status: PTViewControllerStatus = .loggedOut {
        didSet {
            statusDidChange()
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Removes annoying row separators after the last cell
        tableView.tableFooterView = UIView()
    }
    
    func statusDidChange() {
        
        let isTableEmpty = temporaryGrades.isEmpty && passedExams.isEmpty
        
        if isTableEmpty {
            
            navigationItem.titleView = nil
            
            switch status {
            case .logginIn:
                tableView.backgroundView = PTLoadingTableBackgroundView(frame: view.bounds, title: ~"Logging in...")
            case .offline:
                tableView.backgroundView = PTSimpleTableBackgroundView(frame: view.bounds, title: ~"Offline")
            case .error:
                tableView.backgroundView = PTSimpleTableBackgroundView(frame: view.bounds, title: ~"Could not retrieve the data!")
            case .ready:
                tableView.backgroundView = PTSimpleTableBackgroundView(frame: view.bounds, title: ~"No exams on your career!")
            default:
                tableView.backgroundView = nil
            }
            
        } else {
            
            tableView.backgroundView = nil
            
            switch status {
            case .logginIn:
                navigationItem.titleView = PTLoadingTitleView(withTitle: ~"Logging in...")
            case .fetching:
                navigationItem.titleView = PTLoadingTitleView(withTitle: ~"Loading temporary grades...")
            case .offline:
                navigationItem.titleView = PTLoadingTitleView(withTitle: ~"Offline")
            default:
                navigationItem.titleView = nil
            }
            
        }
    }
    
    func handleTabBarItemSelection(wasAlreadySelected: Bool) {
        if wasAlreadySelected {
            tableView.setContentOffset(CGPoint(x: 0, y: -tableView.contentInset.top), animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if tableView.cellForRow(at: indexPath)?.selectionStyle == .none {
            return nil
        } else {
            return indexPath
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        let section = indexPath.section
        let row = indexPath.row
        
        switch section {
        case 0:
            
            (cell as? PTTemporaryGradeCell)?.setTemporaryGrade(temporaryGrades[row])
            
        case 1:
            
            (cell as? PTGradeCell)?.setExam(passedExams[row])
            
        case 2:
            
            (cell as? PTGraphCell)?.setExams(passedExams)
            
        default:
            return
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let section = indexPath.section
        
        switch section {
        case 0:
            return tableView.dequeueReusableCell(withIdentifier: PTTemporaryGradeCell.identifier, for: indexPath)
        case 1:
            return tableView.dequeueReusableCell(withIdentifier: PTGradeCell.identifier, for: indexPath)
        default:
            return tableView.dequeueReusableCell(withIdentifier: PTGraphCell.identifier, for: indexPath)
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        switch section {
        case 0:
            return temporaryGrades.count > 0 ? ~"Temporary Grades" : nil
        case 1:
            return passedExams.count > 0 ? ~"Grades" : nil
        case 2:
            return passedExams.count > 0 ? ~"Overview" : nil
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        switch section {
        case 0:
            return temporaryGrades.count
        case 1:
            return passedExams.count
        case 2:
            return passedExams.count > 0 ? 1 : 0
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        let section = indexPath.section
        
        switch section {
        case 0:
            return PTTemporaryGradeCell.estimatedHeight(temporaryGrade: temporaryGrades[indexPath.row], rowWidth: tableView.frame.width)
        case 1:
            return PTGradeCell.height
        default:
            return PTGraphCell.height
        }
    }
}



class PTGradeCell: UITableViewCell {
    
    @IBOutlet var subjectLabel: UILabel!
    @IBOutlet var gradeLabel: UILabel!
    @IBOutlet var subtitleLabel: UILabel!
    
    static let identifier = "PTGradeCell_id"
    static let height: CGFloat = 70
    
    func setExam(_ exam: PTExam) {
        
        subjectLabel.text = exam.name
        gradeLabel.text = exam.grade.shortDescription
        
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.Turin
        formatter.dateStyle = DateFormatter.Style.medium
        
        let dateStr = formatter.string(from: exam.date)
        subtitleLabel.text = dateStr+" - \(exam.credits) "+(~"ECTS")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.selectionStyle = .none
    }
    
}

class PTTemporaryGradeCell: UITableViewCell {
    
    @IBOutlet var subjectLabel: UILabel!
    @IBOutlet var gradeLabel: UILabel!
    @IBOutlet var subtitleLabel: UILabel!
    @IBOutlet var messageTextView: UITextView!
    
    static let identifier = "PTTemporaryGradeCell_id"
    
    func setTemporaryGrade(_ tempGrade: PTTemporaryGrade) {
        
        subjectLabel.text = tempGrade.subjectName
        gradeLabel.text = tempGrade.grade?.shortDescription ?? ""
        messageTextView.text = tempGrade.message ?? ""
        
        var details: [String] = []
        
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.Turin
        formatter.dateStyle = DateFormatter.Style.medium
        
        let dateStr = formatter.string(from: tempGrade.date)
        details.append(dateStr)
        
        if tempGrade.absent {
            details.append(~"Absent")
        }
        
        if tempGrade.failed {
            details.append(~"Failed")
        }
        
        let stateStr = ~"State"+": "+tempGrade.state
        details.append(stateStr)
        
        subtitleLabel.text = details.joined(separator: " - ")
    }
    
    class func estimatedHeight(temporaryGrade: PTTemporaryGrade, rowWidth: CGFloat) -> CGFloat {
        
        let minimumHeight: CGFloat = 70.0
        let textViewWidth = rowWidth-22.0
        
        guard let bodyText = temporaryGrade.message else {
            return minimumHeight
        }
        
        let textView = UITextView()
        textView.text = bodyText
        textView.font = UIFont.systemFont(ofSize: 13)
        
        let textViewSize = textView.sizeThatFits(CGSize(width: textViewWidth, height: CGFloat.greatestFiniteMagnitude))
        
        return minimumHeight + textViewSize.height + 10.0
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.selectionStyle = .none
    }
}

class PTGraphCell: UITableViewCell {
    
    static let identifier = "PTGraphCell_id"
    static let height: CGFloat = 300
    
    var graphView: ScrollableGraphView?
    private var graphData: [Double] = []
    private var graphLabels: [String] = []
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.selectionStyle = .none
    }
    
    override func draw(_ rect: CGRect) {
    
        graphView?.removeFromSuperview()
        
        graphView = setupBarGraph()
        graphView?.frame = rect
        
        graphView?.setData(data: graphData, withLabels: graphLabels)
        
        addSubview(graphView!)
    }
    
    func setExams(_ exams: [PTExam]) {
        
        let sorted = exams.sorted(by: { (examA, examB) in
            return examA.date.timeIntervalSince(examB.date) < 0
        })
        
        var data: [Double] = []
        var labels: [String] = []
        
        for exam in sorted {
            
            let dataPoint: Double
            
            switch exam.grade {
            case .Passed:
                continue
            case .Honors:
                dataPoint = 30
            case .Numerical(let numb):
                dataPoint = Double(numb)
            }
            
            let labelText = exam.name // PTSubject.abbreviationFromName(exam.name)
            
            data.append(dataPoint)
            labels.append(labelText)
        }
        
        graphData = data
        graphLabels = labels
        
        setNeedsLayout()
    }
    
    func setupBarGraph() -> ScrollableGraphView {
     
        let graphView = ScrollableGraphView()
        
        // Disable the lines and data points.
        graphView.shouldDrawDataPoint = false
        graphView.lineColor = UIColor.clear
        
        // Tell the graph it should draw the bar layer instead.
        graphView.shouldDrawBarLayer = true
        
        graphView.dataPointSpacing = 80
        graphView.leftmostPointPadding = 70
        
        graphView.topMargin = 15
        //graphView.bottomMargin = 80
        
        graphView.dataPointLabelLines = 3
        
        // graphView.dataPointLabelTopMargin = 30
        // graphView.dataPointLabelBottomMargin = 30
        
        // Customise the bar.
        graphView.barWidth = 65
        graphView.barLineWidth = 1
        graphView.barLineColor = UIColor(red:0.47, green:0.47, blue:0.47, alpha:1.0)
        graphView.barColor = UIColor(red:0.33, green:0.33, blue:0.33, alpha:1.0)
        graphView.backgroundFillColor = UIColor(red:0.20, green:0.20, blue:0.20, alpha:1.0)
        
        graphView.referenceLineLabelFont = UIFont.boldSystemFont(ofSize: 8)
        graphView.referenceLineColor = UIColor.white.withAlphaComponent(0.2)
        graphView.referenceLineLabelColor = UIColor.white
        graphView.numberOfIntermediateReferenceLines = 5
        graphView.dataPointLabelColor = UIColor.white.withAlphaComponent(0.5)
        graphView.dataPointLabelFont = UIFont.systemFont(ofSize: 7.0)
        
        graphView.shouldAnimateOnStartup = true
        graphView.shouldAdaptRange = false
        graphView.adaptAnimationType = ScrollableGraphViewAnimationType.Elastic
        graphView.animationDuration = 1.5
        graphView.rangeMax = 30
        graphView.rangeMin = 16
        graphView.shouldRangeAlwaysStartAtZero = true
        
        return graphView
    }
    
    /*
    func setupSmoothGraph() -> ScrollableGraphView {
        
        let graphView = ScrollableGraphView()
        
        graphView.backgroundFillColor = UIColor(red:0.20, green:0.20, blue:0.20, alpha:1.0)
        
        graphView.rangeMax = 30
        graphView.rangeMin = 18
        // graphView.shouldAutomaticallyDetectRange = true
        // graphView.shouldAdaptRange = true
        
        graphView.adaptAnimationType = .Elastic
        
        graphView.lineWidth = 1
        graphView.lineColor = UIColor(red:0.47, green:0.47, blue:0.47, alpha:1.0)
        graphView.lineStyle = ScrollableGraphViewLineStyle.Smooth
        
        graphView.shouldFill = true
        graphView.fillType = ScrollableGraphViewFillType.Gradient
        graphView.fillColor = UIColor(red:0.33, green:0.33, blue:0.33, alpha:1.0)
        graphView.fillGradientType = ScrollableGraphViewGradientType.Linear
        graphView.fillGradientStartColor = UIColor(red:0.33, green:0.33, blue:0.33, alpha:1.0)
        graphView.fillGradientEndColor = UIColor(red:0.27, green:0.27, blue:0.27, alpha:1.0)
        
        graphView.dataPointSpacing = 80
        graphView.dataPointSize = 2
        graphView.dataPointFillColor = UIColor.white
        
        graphView.referenceLineLabelFont = UIFont.boldSystemFont(ofSize: 8)
        graphView.referenceLineColor = UIColor.white.withAlphaComponent(0.2)
        graphView.referenceLineLabelColor = UIColor.white
        graphView.dataPointLabelColor = UIColor.white.withAlphaComponent(0.5)
        
        return graphView
    }
    */
}
