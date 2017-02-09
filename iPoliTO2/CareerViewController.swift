//
//  GradesViewController.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 30/07/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit
import Charts


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
        
        setupRefreshControl()
    }
    
    func statusDidChange() {
        
        if status != .fetching && status != .logginIn {
            refreshControl?.endRefreshing()
        }
        
        let isTableEmpty = temporaryGrades.isEmpty && passedExams.isEmpty
        
        if isTableEmpty {
            
            tableView.isScrollEnabled = false
            navigationItem.titleView = nil
            
            let refreshButton = UIButton(type: .system)
            refreshButton.addTarget(self, action: #selector(refreshButtonPressed), for: .touchUpInside)
            
            switch status {
                
            case .logginIn:
                tableView.backgroundView = PTLoadingTableBackgroundView(frame: view.bounds, title: ~"ls.generic.status.loggingIn")
                
            case .offline:
                refreshButton.setTitle(~"ls.generic.alert.retry", for: .normal)
                tableView.backgroundView = PTSimpleTableBackgroundView(frame: view.bounds, title: ~"ls.generic.status.offline", button: refreshButton)
                
            case .error:
                refreshButton.setTitle(~"ls.generic.alert.retry", for: .normal)
                tableView.backgroundView = PTSimpleTableBackgroundView(frame: view.bounds, title: ~"ls.generic.status.couldNotRetrieve", button: refreshButton)
                
            case .ready:
                refreshButton.setTitle(~"ls.generic.refresh", for: .normal)
                tableView.backgroundView = PTSimpleTableBackgroundView(frame: view.bounds, title: ~"ls.careerVC.status.emptyCareer", button: refreshButton)
                navigationItem.titleView = PTSession.shared.lastUpdateTitleView(title: ~"ls.careerVC.title")
                
            default:
                tableView.backgroundView = nil
            }
            
        } else {
            
            tableView.isScrollEnabled = true
            tableView.backgroundView = nil
            
            switch status {
            case .logginIn:
                navigationItem.titleView = PTLoadingTitleView(withTitle: ~"ls.generic.status.loggingIn")
            case .fetching:
                navigationItem.titleView = PTLoadingTitleView(withTitle: ~"ls.careerVC.status.loading")
            case .offline:
                navigationItem.titleView = PTSession.shared.lastUpdateTitleView(title: ~"ls.generic.status.offline")
            default:
                navigationItem.titleView = PTSession.shared.lastUpdateTitleView(title: ~"ls.careerVC.title")
            }
            
        }
    }
    
    func setupRefreshControl() {
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refreshControlActuated), for: .valueChanged)
    }
    
    @objc
    func refreshControlActuated() {
        if PTSession.shared.isBusy {
            refreshControl?.endRefreshing()
        } else {
            (UIApplication.shared.delegate as! AppDelegate).login()
        }
    }
    
    @objc
    func refreshButtonPressed() {
        (UIApplication.shared.delegate as! AppDelegate).login()
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
            
            (cell as? PTCareerDetailsCell)?.configure(withStudentInfo: PTSession.shared.studentInfo)
            
        case 3:
            
            (cell as? PTGraphCell)?.configure(withExams: passedExams)
            
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
        case 2:
            return tableView.dequeueReusableCell(withIdentifier: PTCareerDetailsCell.identifier, for: indexPath)
        default:
            return tableView.dequeueReusableCell(withIdentifier: PTGraphCell.identifier, for: indexPath)
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        switch section {
        case 0:
            return temporaryGrades.count > 0 ? ~"ls.careerVC.section.tempGrades" : nil
        case 1:
            return passedExams.count > 0 ? ~"ls.careerVC.section.grades" : nil
        case 2:
            return passedExams.count > 0 ? ~"ls.careerVC.section.details" : nil
        case 3:
            return passedExams.count > 0 ? ~"ls.careerVC.section.overview" : nil
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
        case 3:
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
        case 2:
            return PTCareerDetailsCell.height
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
        subtitleLabel.text = dateStr+" - \(exam.credits) "+(~"ls.generic.credits")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.selectionStyle = .none
    }
    
}

class PTCareerDetailsCell: UITableViewCell {
    
    @IBOutlet var weightedAvgLabel: UILabel!
    @IBOutlet var cleanAvgLabel: UILabel!
    @IBOutlet var creditsLabel: UILabel!
    
    static let identifier = "PTCareerDetailsCell_id"
    static let height: CGFloat = 76
    
    func configure(withStudentInfo studentInfo: PTStudentInfo?) {
        
        let formatter = NumberFormatter()
        formatter.allowsFloats = true
        formatter.maximumFractionDigits = 2
        
        let blackAttributes = [NSFontAttributeName: UIFont.systemFont(ofSize: 17.0),
                               NSForegroundColorAttributeName: UIColor.iPoliTO.darkGray]
        
        let grayAttributes = [NSFontAttributeName: UIFont.systemFont(ofSize: 12.0),
                              NSForegroundColorAttributeName: UIColor.lightGray]
        
        
        var weightedAvgStr: String? = nil
        if let weightedAvg = studentInfo?.weightedAverage {
            weightedAvgStr = formatter.string(from: NSNumber(floatLiteral: weightedAvg))
        }
        
        var cleanAvgStr: String? = nil
        if let cleanAvg = studentInfo?.cleanWeightedAverage {
            cleanAvgStr = formatter.string(from: NSNumber(floatLiteral: cleanAvg))
        }
        
        var graduationMarkStr: String? = nil
        if let graduationMark = studentInfo?.graduationMark {
            graduationMarkStr = formatter.string(from: NSNumber(floatLiteral: graduationMark))
        }
        
        var cleanGraduationMarkStr: String? = nil
        if let cleanGraduationMark = studentInfo?.cleanGraduationMark {
            cleanGraduationMarkStr = formatter.string(from: NSNumber(floatLiteral: cleanGraduationMark))
        }
        
        var totalCreditsStr: String? = nil
        if let totalCreditsVal = studentInfo?.totalCredits {
            totalCreditsStr = String(totalCreditsVal)
        }
        
        var obtainedCreditsStr: String? = nil
        if let obtainedCreditsVal = studentInfo?.obtainedCredits {
            obtainedCreditsStr = String(obtainedCreditsVal)
        }
        
        
        let weightedAvgAttrib = NSAttributedString(string: weightedAvgStr ?? "??", attributes: blackAttributes)
        let cleanAvgAttrib = NSAttributedString(string: cleanAvgStr ?? "??", attributes: blackAttributes)
        let graduationMarkAttrib = NSAttributedString(string: graduationMarkStr ?? "??", attributes: blackAttributes)
        let cleanGraduationMarkAttrib = NSAttributedString(string: cleanGraduationMarkStr ?? "??", attributes: blackAttributes)
        let obtainedCreditsAttrib = NSAttributedString(string: obtainedCreditsStr ?? "??", attributes: blackAttributes)
        
        let maximumAverage = NSAttributedString(string: "/30", attributes: grayAttributes)
        let maximumGradMark = NSAttributedString(string: "/110", attributes: grayAttributes)
        let spacesAttrib = NSAttributedString(string: "    ", attributes: [NSFontAttributeName: UIFont.systemFont(ofSize: 17.0)])
        let totalCreditsAttrib = NSAttributedString(string: "/"+(totalCreditsStr ?? "??"), attributes: grayAttributes)
        
        
        let weightedAvgLabelText = NSMutableAttributedString()
        weightedAvgLabelText.append(weightedAvgAttrib)
        weightedAvgLabelText.append(maximumAverage)
        weightedAvgLabelText.append(spacesAttrib)
        weightedAvgLabelText.append(graduationMarkAttrib)
        weightedAvgLabelText.append(maximumGradMark)
        
        let cleanAvgLabelText = NSMutableAttributedString()
        cleanAvgLabelText.append(cleanAvgAttrib)
        cleanAvgLabelText.append(maximumAverage)
        cleanAvgLabelText.append(spacesAttrib)
        cleanAvgLabelText.append(cleanGraduationMarkAttrib)
        cleanAvgLabelText.append(maximumGradMark)
        
        let creditsLabelText = NSMutableAttributedString()
        creditsLabelText.append(obtainedCreditsAttrib)
        creditsLabelText.append(totalCreditsAttrib)
        
        
        weightedAvgLabel.attributedText = weightedAvgLabelText
        cleanAvgLabel.attributedText = cleanAvgLabelText
        creditsLabel.attributedText = creditsLabelText
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
            details.append(~"ls.careerVC.tempGrade.absent")
        }
        
        if tempGrade.failed {
            details.append(~"ls.careerVC.tempGrade.failed")
        }
        
        let stateStr = ~"ls.careerVC.tempGrade.state"+": "+tempGrade.state
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
    
    private var pieChart: PieChartView?
    private var pieChartData: PieChartData?
    
    override func draw(_ rect: CGRect) {
        
        if pieChart == nil {
            
            pieChart = PieChartView()
            pieChart?.noDataText = ~"ls.careerVC.chart.noData"
            pieChart?.descriptionText = ""
            pieChart?.drawEntryLabelsEnabled = false
            pieChart?.usePercentValuesEnabled = false
            pieChart?.transparentCircleRadiusPercent = 0.6
            pieChart?.legend.horizontalAlignment = .center
            pieChart?.setExtraOffsets(left: 0, top: 0, right: 0, bottom: -10)
            pieChart?.isUserInteractionEnabled = false
            
            addSubview(pieChart!)
        }
        
        if let data = pieChartData {
            pieChart?.data = data
        }
        
        pieChart?.frame = CGRect(origin: rect.origin, size: CGSize(width: rect.width, height: (rect.height - 10)))
    }
    
    func configure(withExams exams: [PTExam]) {
        
        var n18_20 = 0.0
        var n21_23 = 0.0
        var n24_26 = 0.0
        var n27_30 = 0.0
        var n30L = 0.0
        
        for exam in exams {
            
            switch exam.grade {
            case .passed:
                continue
            case .honors:
                n30L += 1
            case .numerical(let numb):
                
                if numb >= 18 && numb <= 20 {
                    n18_20 += 1
                } else if numb >= 21 && numb <= 23 {
                    n21_23 += 1
                } else if numb >= 24 && numb <= 26 {
                    n24_26 += 1
                } else if numb >= 27 && numb <= 30 {
                    n27_30 += 1
                }
            }
        }
        
        var entries: [PieChartDataEntry] = []
        var colors: [UIColor] = []
        
        if n18_20 > 0 {
            entries.append(PieChartDataEntry(value: n18_20, label: "18~20"))
            colors.append(#colorLiteral(red: 0.9372549057, green: 0.3490196168, blue: 0.1921568662, alpha: 1))
        }
        if n21_23 > 0 {
            entries.append(PieChartDataEntry(value: n21_23, label: "21~23"))
            colors.append(#colorLiteral(red: 0.9568627477, green: 0.6588235497, blue: 0.5450980663, alpha: 1))
        }
        if n24_26 > 0 {
            entries.append(PieChartDataEntry(value: n24_26, label: "24~26"))
            colors.append(#colorLiteral(red: 0.9764705896, green: 0.850980401, blue: 0.5490196347, alpha: 1))
        }
        if n27_30 > 0 {
            entries.append(PieChartDataEntry(value: n27_30, label: "27~30"))
            colors.append(#colorLiteral(red: 0.721568644, green: 0.8862745166, blue: 0.5921568871, alpha: 1))
        }
        if n30L > 0 {
            entries.append(PieChartDataEntry(value: n30L,   label: "30L"  ))
            colors.append(#colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1))
        }
        
        let set = PieChartDataSet(values: entries, label: nil)
        set.colors = colors
        
        let data = PieChartData(dataSet: set)
        
        let formatter = DefaultValueFormatter()
        formatter.decimals = 0
        data.setValueFormatter(formatter)
        
        pieChartData = data
        pieChart?.data = data
    }
    
    
}
