import SwiftUI

struct HabitView: View {
    @StateObject private var viewModel = HabitViewModel()
    @State private var showingAddHabit = false
    @State private var selectedHabit: Habit?
    @State private var showingFilters = false
    @State private var selectedCategory: HabitCategory?
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var filteredHabits: [Habit] {
        guard let category = selectedCategory else { return viewModel.habits }
        return viewModel.habits.filter { $0.category == category }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Streak Overview
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(viewModel.habits.sorted { $0.streak > $1.streak }) { habit in
                                StreakCard(habit: habit)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Category Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            CategoryButton(
                                title: "All",
                                isSelected: selectedCategory == nil,
                                action: { selectedCategory = nil }
                            )
                            
                            ForEach(HabitCategory.allCases.filter { 
                                if case .custom = $0 { return false }
                                return true
                            }, id: \.self) { category in
                                CategoryButton(
                                    title: category.rawValue.capitalized,
                                    isSelected: selectedCategory == category,
                                    action: { selectedCategory = category }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Habits Grid
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredHabits) { habit in
                            HabitCard(habit: habit, viewModel: viewModel)
                                .onTapGesture {
                                    selectedHabit = habit
                                }
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitle("Habits", displayMode: .large)
            .navigationBarItems(
                trailing: Button(action: { showingAddHabit = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            )
            .sheet(isPresented: $showingAddHabit) {
                AddHabitView(viewModel: viewModel)
            }
            .sheet(item: $selectedHabit) { habit in
                HabitDetailView(habit: habit, viewModel: viewModel)
            }
        }
    }
}

struct StreakCard: View {
    let habit: Habit
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("\(habit.streak) days")
                    .font(.headline)
            }
            
            Text(habit.name)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct HabitCard: View {
    let habit: Habit
    @ObservedObject var viewModel: HabitViewModel
    
    var progress: Double {
        viewModel.getProgress(for: habit, on: Date()) ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconName(for: habit.category))
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Spacer()
                
                if habit.streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("\(habit.streak)")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                }
            }
            
            Text(habit.name)
                .font(.headline)
            
            if let target = habit.target {
                Text("\(Int(progress))/\(Int(target.value)) \(target.unit)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            ProgressBar(progress: progress / habit.target.value)
                .frame(height: 6)
            
            if let reminder = habit.reminder, reminder.isEnabled {
                HStack {
                    Image(systemName: "bell.fill")
                        .font(.caption)
                    Text(timeString(from: reminder.time))
                        .font(.caption)
                }
                .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
    
    private func iconName(for category: HabitCategory) -> String {
        switch category {
        case .fitness: return "figure.walk"
        case .health: return "heart.fill"
        case .productivity: return "checkmark.circle.fill"
        case .mindfulness: return "brain.head.profile"
        case .learning: return "book.fill"
        case .custom: return "star.fill"
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ProgressBar: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .cornerRadius(3)
                
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: min(CGFloat(progress) * geometry.size.width, geometry.size.width))
                    .cornerRadius(3)
            }
        }
    }
} 