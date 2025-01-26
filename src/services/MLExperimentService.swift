import Foundation
import MongoDBVapor
import Vapor

struct ExperimentConfig: Codable {
    let id: String
    let name: String
    let startDate: Date
    let endDate: Date?
    let parameters: [String: Double]
    var metrics: [String: Double]
    let isActive: Bool
}

struct AnomalyDetection: Codable {
    let userId: String
    let timestamp: Date
    let type: String
    let metric: String
    let expectedValue: Double
    let actualValue: Double
    let zScore: Double
    let description: String
}

// Statistical test results
struct StatisticalTestResults: Codable {
    let tValue: Double
    let pValue: Double
    let effectSize: Double
    let confidenceInterval: (lower: Double, upper: Double)
    let degreesOfFreedom: Int
    let isSignificant: Bool
}

final class MLExperimentService {
    private let database: MongoDatabase
    private let experimentsCollection: MongoCollection<ExperimentConfig>
    private let anomaliesCollection: MongoCollection<AnomalyDetection>
    private let analyticsService: MLAnalyticsService
    
    // Statistical parameters for anomaly detection
    private let anomalyThreshold: Double = 2.5 // Z-score threshold
    private let minDataPoints: Int = 10
    
    init(database: MongoDatabase, analyticsService: MLAnalyticsService) {
        self.database = database
        self.experimentsCollection = database.collection("ml_experiments", withType: ExperimentConfig.self)
        self.anomaliesCollection = database.collection("ml_anomalies", withType: AnomalyDetection.self)
        self.analyticsService = analyticsService
    }
    
    // Create a new A/B test experiment
    func createExperiment(name: String, parameters: [String: Double], durationInDays: Int) async throws {
        let experiment = ExperimentConfig(
            id: UUID().uuidString,
            name: name,
            startDate: Date(),
            endDate: Date().addingTimeInterval(TimeInterval(durationInDays * 24 * 3600)),
            parameters: parameters,
            metrics: [:],
            isActive: true
        )
        
        try await experimentsCollection.insertOne(experiment)
    }
    
    // Get active experiment parameters for a user
    func getExperimentParameters(userId: String) async throws -> [String: Double] {
        // Use user ID to consistently assign users to experiment groups
        let activeExperiments = try await experimentsCollection
            .find(["isActive": true])
            .toArray()
        
        guard let experiment = activeExperiments.first else {
            return [:] // Return default parameters if no active experiment
        }
        
        // Use hash of user ID to consistently assign to groups
        let userHash = userId.hash
        let isInExperimentGroup = abs(userHash) % 2 == 0 // 50/50 split
        
        if isInExperimentGroup {
            return experiment.parameters
        } else {
            return [:] // Control group gets default parameters
        }
    }
    
    // Record experiment metrics
    func recordExperimentMetrics(experimentId: String, metrics: [String: Double]) async throws {
        try await experimentsCollection.updateOne(
            where: ["id": experimentId],
            to: ["$set": ["metrics": metrics]]
        )
    }
    
    // Get control group metrics for experiment analysis
    private func getControlGroupMetrics(experimentId: String) async throws -> [String: Double]? {
        guard let experiment = try await experimentsCollection.findOne(["id": experimentId]) else {
            return nil
        }
        
        // Get all metrics for the experiment timeframe
        let metrics = try await analyticsService.metricsCollection
            .find([
                "timestamp": [
                    "$gte": experiment.startDate,
                    "$lte": experiment.endDate ?? Date()
                ]
            ])
            .toArray()
        
        // Group metrics by control/experiment groups
        var controlGroupMetrics: [String: [Double]] = [:]
        
        for metric in metrics {
            // Use hash of user ID to determine group
            let isInExperimentGroup = abs(metric.userId.hash) % 2 == 0
            
            if !isInExperimentGroup {
                // Add to control group metrics
                if let predictedTime = metric.predictedTimeToComplete,
                   let actualTime = metric.actualTimeToComplete {
                    let timeError = abs(predictedTime - actualTime) / actualTime
                    controlGroupMetrics["timeEstimationError", default: []].append(timeError)
                }
                
                controlGroupMetrics["predictionAccuracy", default: []].append(
                    metric.actualSuccess == (metric.predictedScore >= 0.7) ? 1.0 : 0.0
                )
            }
        }
        
        // Calculate averages for control group
        return controlGroupMetrics.mapValues { values in
            values.reduce(0.0, +) / Double(values.count)
        }
    }
    
    // Calculate statistical significance and other metrics
    private func calculateStatisticalSignificance(
        experimentMetrics: [String: Double],
        controlMetrics: [String: Double]
    ) -> [String: StatisticalTestResults] {
        var results: [String: StatisticalTestResults] = [:]
        
        for (metric, experimentValue) in experimentMetrics {
            guard let controlValue = controlMetrics[metric] else { continue }
            
            // Get raw data for both groups
            let experimentData = try? await getRawMetricData(metric: metric, isExperimentGroup: true)
            let controlData = try? await getRawMetricData(metric: metric, isExperimentGroup: false)
            
            if let expData = experimentData, let ctrlData = controlData,
               !expData.isEmpty && !ctrlData.isEmpty {
                
                // Calculate t-test and other statistics
                let testResults = performTTest(
                    experimentGroup: expData,
                    controlGroup: ctrlData
                )
                
                results[metric] = testResults
            }
        }
        
        return results
    }
    
    // Get raw metric data for statistical analysis
    private func getRawMetricData(metric: String, isExperimentGroup: Bool) async throws -> [Double] {
        let activeExperiments = try await experimentsCollection
            .find(["isActive": true])
            .toArray()
        
        guard let experiment = activeExperiments.first else { return [] }
        
        // Query metrics based on experiment timeframe and group
        let metrics = try await analyticsService.metricsCollection
            .find([
                "timestamp": [
                    "$gte": experiment.startDate,
                    "$lte": experiment.endDate ?? Date()
                ]
            ])
            .toArray()
        
        return metrics.compactMap { metric -> Double? in
            let userInExperimentGroup = abs(metric.userId.hash) % 2 == 0
            guard userInExperimentGroup == isExperimentGroup else { return nil }
            
            switch metric {
            case "timeEstimationError":
                guard let predicted = metric.predictedTimeToComplete,
                      let actual = metric.actualTimeToComplete else {
                    return nil
                }
                return abs(predicted - actual) / actual
                
            case "predictionAccuracy":
                return metric.actualSuccess == (metric.predictedScore >= 0.7) ? 1.0 : 0.0
                
            default:
                return nil
            }
        }
    }
    
    // Perform t-test and calculate related statistics
    private func performTTest(experimentGroup: [Double], controlGroup: [Double]) -> StatisticalTestResults {
        let n1 = Double(experimentGroup.count)
        let n2 = Double(controlGroup.count)
        
        // Calculate means
        let mean1 = experimentGroup.reduce(0.0, +) / n1
        let mean2 = controlGroup.reduce(0.0, +) / n2
        
        // Calculate variances
        let variance1 = experimentGroup.reduce(0.0) { sum, x in
            let diff = x - mean1
            return sum + (diff * diff)
        } / (n1 - 1)
        
        let variance2 = controlGroup.reduce(0.0) { sum, x in
            let diff = x - mean2
            return sum + (diff * diff)
        } / (n2 - 1)
        
        // Pooled standard error
        let pooledSE = sqrt((variance1 / n1) + (variance2 / n2))
        
        // Calculate t-value
        let tValue = (mean1 - mean2) / pooledSE
        
        // Degrees of freedom (Welch's approximation)
        let numerator = pow((variance1 / n1) + (variance2 / n2), 2)
        let denominator = pow(variance1 / n1, 2) / (n1 - 1) + pow(variance2 / n2, 2) / (n2 - 1)
        let df = Int(round(numerator / denominator))
        
        // Calculate p-value (two-tailed)
        let pValue = calculatePValue(tValue: abs(tValue), degreesOfFreedom: df)
        
        // Calculate effect size (Cohen's d)
        let pooledSD = sqrt(((n1 - 1) * variance1 + (n2 - 1) * variance2) / (n1 + n2 - 2))
        let effectSize = (mean1 - mean2) / pooledSD
        
        // Calculate 95% confidence interval
        let criticalValue = 1.96 // For 95% confidence level
        let marginOfError = criticalValue * pooledSE
        let confidenceInterval = (
            lower: mean1 - mean2 - marginOfError,
            upper: mean1 - mean2 + marginOfError
        )
        
        return StatisticalTestResults(
            tValue: tValue,
            pValue: pValue,
            effectSize: effectSize,
            confidenceInterval: confidenceInterval,
            degreesOfFreedom: df,
            isSignificant: pValue < 0.05
        )
    }
    
    // Calculate p-value using Student's t-distribution
    private func calculatePValue(tValue: Double, degreesOfFreedom: Int) -> Double {
        // This is a simplified approximation of the p-value calculation
        // In a production environment, you would use a more precise statistical library
        let x = degreesOfFreedom / (degreesOfFreedom + tValue * tValue)
        let beta = betaFunction(a: 0.5 * Double(degreesOfFreedom), b: 0.5)
        
        return 1.0 - incompleteBetaFunction(x: x, a: 0.5 * Double(degreesOfFreedom), b: 0.5) / beta
    }
    
    // Beta function for p-value calculation
    private func betaFunction(a: Double, b: Double) -> Double {
        return exp(logGamma(a) + logGamma(b) - logGamma(a + b))
    }
    
    // Log gamma function approximation
    private func logGamma(_ x: Double) -> Double {
        let p = [676.5203681218851, -1259.1392167224028,
                771.32342877765313, -176.61502916214059,
                12.507343278686905, -0.13857109526572012,
                9.9843695780195716e-6, 1.5056327351493116e-7]
        
        var result = 0.99999999999980993
        for (i, pValue) in p.enumerated() {
            result += pValue / (x + Double(i))
        }
        
        let t = x + 7.5
        return log(sqrt(2 * .pi)) + (x + 0.5) * log(t) - t + log(result)
    }
    
    // Incomplete beta function approximation
    private func incompleteBetaFunction(x: Double, a: Double, b: Double) -> Double {
        let maxIterations = 100
        let epsilon = 1e-10
        
        var result = 0.0
        var term = 1.0
        
        for n in 0..<maxIterations {
            term *= (a + Double(n)) * x / (a + b + Double(n))
            result += term
            
            if abs(term) < epsilon { break }
        }
        
        return result * pow(x, a) * pow(1 - x, b) / a
    }
    
    // Analyze experiment results with enhanced statistics
    func analyzeExperiment(experimentId: String) async throws -> [String: Any] {
        guard let experiment = try await experimentsCollection.findOne(["id": experimentId]) else {
            throw Abort(.notFound)
        }
        
        var results: [String: Any] = [
            "experimentName": experiment.name,
            "startDate": experiment.startDate,
            "parameters": experiment.parameters
        ]
        
        // Calculate improvement metrics
        if let controlMetrics = try await getControlGroupMetrics(experimentId: experimentId),
           let experimentMetrics = experiment.metrics {
            
            var improvements: [String: Double] = [:]
            var statisticalResults: [String: [String: Any]] = [:]
            
            for (metric, experimentValue) in experimentMetrics {
                if let controlValue = controlMetrics[metric] {
                    let improvement = ((experimentValue - controlValue) / controlValue) * 100
                    improvements[metric] = improvement
                    
                    // Get detailed statistical analysis
                    if let testResults = calculateStatisticalSignificance(
                        experimentMetrics: [metric: experimentValue],
                        controlMetrics: [metric: controlValue]
                    )[metric] {
                        statisticalResults[metric] = [
                            "tValue": testResults.tValue,
                            "pValue": testResults.pValue,
                            "effectSize": testResults.effectSize,
                            "confidenceInterval": [
                                "lower": testResults.confidenceInterval.lower,
                                "upper": testResults.confidenceInterval.upper
                            ],
                            "degreesOfFreedom": testResults.degreesOfFreedom,
                            "isSignificant": testResults.isSignificant
                        ]
                    }
                }
            }
            
            results["improvements"] = improvements
            results["statisticalAnalysis"] = statisticalResults
        }
        
        return results
    }
    
    // Detect anomalies in user behavior
    func detectAnomalies(userId: String) async throws {
        // Get recent metrics
        let metrics = try await analyticsService.getPerformanceMetrics(for: userId)
        
        // Check task completion patterns
        if let categoryMetrics = metrics["categoryMetrics"] as? [String: [String: Double]] {
            for (category, data) in categoryMetrics {
                if let successRate = data["successRate"] {
                    try await detectSuccessRateAnomaly(
                        userId: userId,
                        category: category,
                        currentRate: successRate
                    )
                }
            }
        }
        
        // Check time estimation accuracy
        if let timeError = metrics["timeEstimationError"] as? Double {
            try await detectTimeEstimationAnomaly(
                userId: userId,
                currentError: timeError
            )
        }
        
        // Check prediction accuracy
        if let accuracy = metrics["predictionAccuracy"] as? Double {
            try await detectPredictionAccuracyAnomaly(
                userId: userId,
                currentAccuracy: accuracy
            )
        }
    }
    
    // Detect anomalies in success rates
    private func detectSuccessRateAnomaly(userId: String, category: String, currentRate: Double) async throws {
        // Get historical success rates
        let historicalRates = try await getHistoricalSuccessRates(userId: userId, category: category)
        
        if historicalRates.count >= minDataPoints {
            let (mean, stdDev) = calculateStatistics(historicalRates)
            let zScore = abs((currentRate - mean) / stdDev)
            
            if zScore > anomalyThreshold {
                let anomaly = AnomalyDetection(
                    userId: userId,
                    timestamp: Date(),
                    type: "success_rate",
                    metric: category,
                    expectedValue: mean,
                    actualValue: currentRate,
                    zScore: zScore,
                    description: "Unusual success rate detected for category: \(category)"
                )
                
                try await anomaliesCollection.insertOne(anomaly)
            }
        }
    }
    
    // Detect anomalies in time estimation
    private func detectTimeEstimationAnomaly(userId: String, currentError: Double) async throws {
        let historicalErrors = try await getHistoricalTimeErrors(userId: userId)
        
        if historicalErrors.count >= minDataPoints {
            let (mean, stdDev) = calculateStatistics(historicalErrors)
            let zScore = abs((currentError - mean) / stdDev)
            
            if zScore > anomalyThreshold {
                let anomaly = AnomalyDetection(
                    userId: userId,
                    timestamp: Date(),
                    type: "time_estimation",
                    metric: "error_rate",
                    expectedValue: mean,
                    actualValue: currentError,
                    zScore: zScore,
                    description: "Unusual time estimation error detected"
                )
                
                try await anomaliesCollection.insertOne(anomaly)
            }
        }
    }
    
    // Detect anomalies in prediction accuracy
    private func detectPredictionAccuracyAnomaly(userId: String, currentAccuracy: Double) async throws {
        let historicalAccuracy = try await getHistoricalPredictionAccuracy(userId: userId)
        
        if historicalAccuracy.count >= minDataPoints {
            let (mean, stdDev) = calculateStatistics(historicalAccuracy)
            let zScore = abs((currentAccuracy - mean) / stdDev)
            
            if zScore > anomalyThreshold {
                let anomaly = AnomalyDetection(
                    userId: userId,
                    timestamp: Date(),
                    type: "prediction_accuracy",
                    metric: "accuracy",
                    expectedValue: mean,
                    actualValue: currentAccuracy,
                    zScore: zScore,
                    description: "Unusual prediction accuracy detected"
                )
                
                try await anomaliesCollection.insertOne(anomaly)
            }
        }
    }
    
    // Get historical success rates for a category
    private func getHistoricalSuccessRates(userId: String, category: String) async throws -> [Double] {
        let metrics = try await analyticsService.metricsCollection
            .find([
                "userId": userId,
                "category": category
            ])
            .sort(["timestamp": -1])
            .limit(100)
            .toArray()
        
        return metrics.map { $0.actualSuccess ? 1.0 : 0.0 }
    }
    
    // Get historical time estimation errors
    private func getHistoricalTimeErrors(userId: String) async throws -> [Double] {
        let metrics = try await analyticsService.metricsCollection
            .find([
                "userId": userId,
                "predictedTimeToComplete": ["$exists": true],
                "actualTimeToComplete": ["$exists": true]
            ])
            .sort(["timestamp": -1])
            .limit(100)
            .toArray()
        
        return metrics.compactMap { metric -> Double? in
            guard let predicted = metric.predictedTimeToComplete,
                  let actual = metric.actualTimeToComplete else {
                return nil
            }
            return abs(predicted - actual) / actual
        }
    }
    
    // Get historical prediction accuracy
    private func getHistoricalPredictionAccuracy(userId: String) async throws -> [Double] {
        let metrics = try await analyticsService.metricsCollection
            .find(["userId": userId])
            .sort(["timestamp": -1])
            .limit(100)
            .toArray()
        
        return metrics.map { metric in
            let wasCorrect = (metric.predictedScore >= 0.7 && metric.actualSuccess) ||
                           (metric.predictedScore < 0.7 && !metric.actualSuccess)
            return wasCorrect ? 1.0 : 0.0
        }
    }
    
    // Helper function to calculate mean and standard deviation
    private func calculateStatistics(_ values: [Double]) -> (mean: Double, stdDev: Double) {
        let count = Double(values.count)
        let mean = values.reduce(0.0, +) / count
        
        let sumSquaredDiff = values.reduce(0.0) { sum, value in
            let diff = value - mean
            return sum + (diff * diff)
        }
        
        let stdDev = sqrt(sumSquaredDiff / count)
        return (mean, stdDev)
    }
} 