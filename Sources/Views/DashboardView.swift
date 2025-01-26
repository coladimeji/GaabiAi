import SwiftUI
import CoreLocation

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var selectedTab = 0
    @State private var showingNewTaskSheet = false
    @State private var showingNewHabitSheet = false
    @State private var isRecording = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Today View
            NavigationView {
                TodayView(viewModel: viewModel)
            }
            .tabItem {
                Label("Today", systemImage: "calendar")
            }
            .tag(0)
            
            // Tasks View
            NavigationView {
                TaskListView(viewModel: viewModel)
            }
            .tabItem {
                Label("Tasks", systemImage: "checklist")
            }
            .tag(1)
            
            // Habits View
            NavigationView {
                HabitListView(viewModel: viewModel)
            }
            .tabItem {
                Label("Habits", systemImage: "repeat")
            }
            .tag(2)
            
            // Smart Home View
            NavigationView {
                SmartHomeView(viewModel: viewModel)
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(3)
            
            // Settings View
            NavigationView {
                SettingsView(viewModel: viewModel)
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(4)
        }
        .overlay(alignment: .bottom) {
            if selectedTab < 3 {
                QuickActionButton(
                    isRecording: $isRecording,
                    showingNewTaskSheet: $showingNewTaskSheet,
                    showingNewHabitSheet: $showingNewHabitSheet,
                    selectedTab: selectedTab
                )
                .padding(.bottom, 85)
            }
        }
    }
}

struct TodayView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var showingScheduleOptimization = false
    
    var body: some View {
        List {
            // Weather Section
            if let weather = viewModel.currentWeather {
                WeatherSummaryView(weather: weather)
            }
            
            // Schedule Section
            Section("Today's Schedule") {
                ForEach(viewModel.todayEvents) { event in
                    ScheduleEventRow(event: event)
                }
            }
            
            // Tasks Section
            Section("Tasks") {
                ForEach(viewModel.todayTasks) { task in
                    TaskRow(task: task)
                }
            }
            
            // Habits Section
            Section("Habits") {
                ForEach(viewModel.todayHabits) { habit in
                    HabitRow(habit: habit)
                }
            }
            
            // Smart Home Section
            if !viewModel.activeDevices.isEmpty {
                Section("Active Devices") {
                    ForEach(viewModel.activeDevices) { device in
                        SmartDeviceRow(device: device)
                    }
                }
            }
        }
        .navigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingScheduleOptimization = true
                } label: {
                    Image(systemName: "wand.and.stars")
                }
            }
        }
        .sheet(isPresented: $showingScheduleOptimization) {
            ScheduleOptimizationView(viewModel: viewModel)
        }
        .refreshable {
            await viewModel.refreshData()
        }
    }
}

struct WeatherSummaryView: View {
    let weather: CurrentWeather
    
    var body: some View {
        HStack {
            Image(systemName: weather.getWeatherIcon())
                .font(.title)
            VStack(alignment: .leading) {
                Text("\(Int(round(weather.temp)))°C")
                    .font(.title2)
                Text(weather.weather.first?.description.capitalized ?? "")
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 8)
    }
}

struct ScheduleEventRow: View {
    let event: ScheduleEvent
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(event.title)
                    .font(.headline)
                Spacer()
                Text(formatTime(event.timeSlot.start))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let location = event.location {
                Label(location.address, systemImage: "location")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let routeInfo = event.routeInfo {
                Label(
                    "\(Int(routeInfo.estimatedDuration / 60)) min travel time",
                    systemImage: "car"
                )
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct TaskRow: View {
    let task: SmartTask
    
    var body: some View {
        HStack {
            Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.status == .completed ? .green : .gray)
            
            VStack(alignment: .leading) {
                Text(task.title)
                    .strikethrough(task.status == .completed)
                
                if !task.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Array(task.tags), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            if task.isOverdue {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }
}

struct HabitRow: View {
    let habit: Habit
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(habit.title)
                    .font(.headline)
                Text("Streak: \(habit.currentStreak) days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(habit.completedDates.count)/\(habit.frequency.description)")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.2))
                .cornerRadius(8)
        }
    }
}

struct SmartDeviceRow: View {
    let device: IoTDevice
    
    var body: some View {
        HStack {
            Image(systemName: iconForDevice(device.type))
                .foregroundColor(device.isConnected ? .green : .gray)
            
            Text(device.name)
            
            Spacer()
            
            if device.isConnected {
                Text("Connected")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Text("Disconnected")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func iconForDevice(_ type: IoTDeviceType) -> String {
        switch type {
        case .smartLight: return "lightbulb"
        case .thermostat: return "thermometer"
        case .speaker: return "speaker.wave.2"
        case .lock: return "lock"
        case .camera: return "camera"
        case .sensor: return "sensor"
        }
    }
}

struct QuickActionButton: View {
    @Binding var isRecording: Bool
    @Binding var showingNewTaskSheet: Bool
    @Binding var showingNewHabitSheet: Bool
    let selectedTab: Int
    
    var body: some View {
        Button {
            switch selectedTab {
            case 0: // Today - Voice Note
                isRecording.toggle()
            case 1: // Tasks
                showingNewTaskSheet = true
            case 2: // Habits
                showingNewHabitSheet = true
            default:
                break
            }
        } label: {
            Image(systemName: iconForTab)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(colorForTab)
                .clipShape(Circle())
                .shadow(radius: 4)
        }
    }
    
    private var iconForTab: String {
        switch selectedTab {
        case 0: return isRecording ? "stop.circle.fill" : "mic.circle.fill"
        case 1: return "plus.circle.fill"
        case 2: return "plus.circle.fill"
        default: return "plus.circle.fill"
        }
    }
    
    private var colorForTab: Color {
        switch selectedTab {
        case 0: return isRecording ? .red : .blue
        case 1: return .blue
        case 2: return .green
        default: return .blue
        }
    }
}

class DashboardViewModel: ObservableObject {
    @Published var todayEvents: [ScheduleEvent] = []
    @Published var todayTasks: [SmartTask] = []
    @Published var todayHabits: [Habit] = []
    @Published var activeDevices: [IoTDevice] = []
    @Published var currentWeather: CurrentWeather?
    
    private let scheduleManager: DailyScheduleManager
    private let habitTracker: HabitTracker
    private let smartHomeManager: SmartHomeManager
    private let weatherClient: OpenWeatherClient
    private let locationManager: LocationManager
    
    init(
        scheduleManager: DailyScheduleManager,
        habitTracker: HabitTracker,
        smartHomeManager: SmartHomeManager,
        weatherClient: OpenWeatherClient,
        locationManager: LocationManager
    ) {
        self.scheduleManager = scheduleManager
        self.habitTracker = habitTracker
        self.smartHomeManager = smartHomeManager
        self.weatherClient = weatherClient
        self.locationManager = locationManager
        
        Task {
            await refreshData()
        }
    }
    
    @MainActor
    func refreshData() async {
        // Fetch today's schedule
        if let schedule = try? await scheduleManager.createSchedule(for: Date()) {
            todayEvents = schedule.events
        }
        
        // Fetch weather
        if let location = await locationManager.getCurrentLocation() {
            if let weather = try? await weatherClient.getCurrentWeather(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            ) {
                currentWeather = weather.current
            }
        }
        
        // TODO: Implement other data fetching
    }
} 