import SwiftUI

struct TaskCalendarView: View {
    @ObservedObject var viewModel: TaskViewModel
    @State private var selectedDate = Date()
    @State private var showingNewTaskSheet = false
    @State private var showingDatePicker = false
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Calendar Header
                HStack {
                    Button(action: previousMonth) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.blue)
                    }
                    
                    Text(dateFormatter.string(from: selectedDate))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                    
                    Button(action: nextMonth) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                
                // Calendar Grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                        Text(day)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                    }
                    
                    ForEach(daysInMonth(), id: \.self) { date in
                        if let date = date {
                            DayCell(
                                date: date,
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                hasTask: viewModel.getTasksForDate(date).count > 0
                            )
                            .onTapGesture {
                                selectedDate = date
                            }
                        } else {
                            Color.clear
                        }
                    }
                }
                .padding()
                
                // Tasks List
                List {
                    Section(header: Text("Tasks for \(dayFormatter.string(from: selectedDate))")) {
                        ForEach(viewModel.getTasksForDate(selectedDate)) { task in
                            TaskRow(task: task, viewModel: viewModel)
                        }
                        
                        if viewModel.getTasksForDate(selectedDate).isEmpty {
                            Text("No tasks scheduled")
                                .foregroundColor(.gray)
                                .italic()
                        }
                    }
                }
            }
            .navigationBarTitle("Calendar", displayMode: .inline)
            .navigationBarItems(
                trailing: Button(action: { showingNewTaskSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            )
            .sheet(isPresented: $showingNewTaskSheet) {
                NewTaskView(viewModel: viewModel, selectedDate: selectedDate)
            }
        }
    }
    
    private func daysInMonth() -> [Date?] {
        let interval = calendar.dateInterval(of: .month, for: selectedDate)!
        let firstDay = interval.start
        
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let daysInMonth = calendar.range(of: .day, in: .month, for: selectedDate)!.count
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        
        let remainingCells = 42 - days.count
        days += Array(repeating: nil, count: remainingCells)
        
        return days
    }
    
    private func previousMonth() {
        selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
    }
    
    private func nextMonth() {
        selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
    }
    
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let hasTask: Bool
    
    private let calendar = Calendar.current
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.blue : Color.clear)
                .opacity(0.2)
            
            VStack {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16))
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundColor(isSelected ? .blue : .primary)
                
                if hasTask {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 4, height: 4)
                }
            }
        }
        .frame(height: 40)
    }
}

struct TaskRow: View {
    let task: Task
    @ObservedObject var viewModel: TaskViewModel
    @State private var showingTaskDetail = false
    
    var body: some View {
        Button(action: { showingTaskDetail = true }) {
            HStack {
                VStack(alignment: .leading) {
                    Text(task.title)
                        .font(.headline)
                    
                    if !task.description.isEmpty {
                        Text(task.description)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if task.hasReminder {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.blue)
                    }
                    
                    if task.weatherAlert {
                        Image(systemName: "cloud.sun.fill")
                            .foregroundColor(.orange)
                    }
                    
                    if task.trafficAlert {
                        Image(systemName: "car.fill")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .sheet(isPresented: $showingTaskDetail) {
            TaskDetailView(task: task, viewModel: viewModel)
        }
    }
} 