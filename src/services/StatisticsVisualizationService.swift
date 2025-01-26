import Foundation
import Vapor
import MongoDBVapor
import SwiftPlot
import SVGRenderer

struct VisualizationData: Codable {
    let id: String
    let type: String
    let svgContent: String
    let title: String
    let description: String
    let timestamp: Date
    let interactiveElements: [InteractiveElement]
    let rawData: [String: [Double]]  // Store raw data for client-side interactions
}

struct InteractiveElement: Codable {
    let elementId: String
    let type: InteractionType
    let data: [String: String]
    let tooltipContent: String?
}

enum InteractionType: String, Codable {
    case tooltip
    case clickable
    case zoomable
    case hoverable
}

final class StatisticsVisualizationService {
    private let database: MongoDatabase
    private let visualizationsCollection: MongoCollection<VisualizationData>
    
    init(database: MongoDatabase) {
        self.database = database
        self.visualizationsCollection = database.collection("visualizations", withType: VisualizationData.self)
    }
    
    // Generate experiment results visualization
    func visualizeExperimentResults(
        experimentId: String,
        results: [String: Any]
    ) async throws -> VisualizationData {
        guard let improvements = results["improvements"] as? [String: Double],
              let analysis = results["statisticalAnalysis"] as? [String: [String: Any]] else {
            throw Abort(.badRequest)
        }
        
        // Create interactive bar chart
        let (barChart, barInteractions) = try createInteractiveImprovementsBarChart(
            improvements: improvements,
            analysis: analysis
        )
        
        // Create interactive effect size plot
        let (effectSizePlot, effectSizeInteractions) = try createInteractiveEffectSizePlot(
            analysis: analysis
        )
        
        // Combine visualizations and interactions
        let combinedSVG = combineVisualizations([barChart, effectSizePlot])
        let allInteractions = barInteractions + effectSizeInteractions
        
        // Store raw data for client-side interactions
        let rawData: [String: [Double]] = [
            "improvements": improvements.values.map { $0 },
            "effectSizes": analysis.values.compactMap { ($0["effectSize"] as? Double) ?? nil }
        ]
        
        let visualization = VisualizationData(
            id: UUID().uuidString,
            type: "experiment_results",
            svgContent: combinedSVG,
            title: "Experiment Results Visualization",
            description: createVisualizationDescription(results: results),
            timestamp: Date(),
            interactiveElements: allInteractions,
            rawData: rawData
        )
        
        try await visualizationsCollection.insertOne(visualization)
        return visualization
    }
    
    // Generate interactive anomaly visualization
    func visualizeAnomaly(
        anomaly: AnomalyDetection,
        historicalData: [Double]
    ) async throws -> VisualizationData {
        // Create interactive time series plot
        let (timeSeriesPlot, timeSeriesInteractions) = try createInteractiveAnomalyTimeSeries(
            historicalData: historicalData,
            anomalyPoint: anomaly.actualValue,
            expectedValue: anomaly.expectedValue,
            zScore: anomaly.zScore
        )
        
        // Create interactive distribution plot
        let (distributionPlot, distributionInteractions) = try createInteractiveDistributionPlot(
            historicalData: historicalData,
            anomalyValue: anomaly.actualValue
        )
        
        // Combine visualizations and interactions
        let combinedSVG = combineVisualizations([timeSeriesPlot, distributionPlot])
        let allInteractions = timeSeriesInteractions + distributionInteractions
        
        // Store raw data for client-side interactions
        let rawData: [String: [Double]] = [
            "historicalData": historicalData,
            "anomalyPoint": [anomaly.actualValue],
            "expectedValue": [anomaly.expectedValue]
        ]
        
        let visualization = VisualizationData(
            id: UUID().uuidString,
            type: "anomaly_detection",
            svgContent: combinedSVG,
            title: "Anomaly Detection Visualization",
            description: createAnomalyDescription(anomaly: anomaly),
            timestamp: Date(),
            interactiveElements: allInteractions,
            rawData: rawData
        )
        
        try await visualizationsCollection.insertOne(visualization)
        return visualization
    }
    
    // Private helper methods for interactive visualizations
    
    private func createInteractiveImprovementsBarChart(
        improvements: [String: Double],
        analysis: [String: [String: Any]]
    ) throws -> (String, [InteractiveElement]) {
        var plot = Plot(title: "Experiment Improvements")
        plot.addAxis(axis: .left, title: "Improvement (%)")
        plot.addAxis(axis: .bottom, title: "Metrics")
        
        let metrics = improvements.keys.sorted()
        let values = metrics.map { improvements[$0]! }
        
        // Add interactive bars
        var barGraph = BarGraph(values: values)
        barGraph.labels = metrics
        
        // Create interactive elements for each bar
        var interactions: [InteractiveElement] = []
        for (index, metric) in metrics.enumerated() {
            let improvement = values[index]
            let stats = analysis[metric] as? [String: Any]
            let isSignificant = (stats?["isSignificant"] as? Bool) ?? false
            
            let elementId = "bar-\(metric.replacingOccurrences(of: " ", with: "-"))"
            barGraph.addInteractiveElement(id: elementId)
            
            // Create tooltip content
            let tooltipContent = """
            Metric: \(metric)
            Improvement: \(String(format: "%.1f", improvement))%
            Statistical Significance: \(isSignificant ? "Yes" : "No")
            """
            
            interactions.append(InteractiveElement(
                elementId: elementId,
                type: .hoverable,
                data: [
                    "metric": metric,
                    "improvement": String(improvement),
                    "isSignificant": String(isSignificant)
                ],
                tooltipContent: tooltipContent
            ))
        }
        
        plot.add(barGraph)
        
        // Render to SVG
        let renderer = SVGRenderer()
        plot.drawGraph(renderer: renderer)
        return (renderer.svgOutput, interactions)
    }
    
    private func createInteractiveEffectSizePlot(
        analysis: [String: [String: Any]]
    ) throws -> (String, [InteractiveElement]) {
        var plot = Plot(title: "Effect Sizes")
        plot.addAxis(axis: .left, title: "Effect Size (Cohen's d)")
        plot.addAxis(axis: .bottom, title: "Metrics")
        
        let metrics = analysis.keys.sorted()
        var interactions: [InteractiveElement] = []
        
        // Add interactive scatter plot
        for (index, metric) in metrics.enumerated() {
            guard let stats = analysis[metric] as? [String: Any],
                  let effectSize = stats["effectSize"] as? Double,
                  let ci = stats["confidenceInterval"] as? [String: Double] else {
                continue
            }
            
            let elementId = "effect-\(metric.replacingOccurrences(of: " ", with: "-"))"
            
            // Create tooltip content
            let tooltipContent = """
            Metric: \(metric)
            Effect Size: \(String(format: "%.2f", effectSize))
            95% CI: [\(String(format: "%.2f", ci["lower"]!)), \(String(format: "%.2f", ci["upper"]!))]
            """
            
            interactions.append(InteractiveElement(
                elementId: elementId,
                type: .hoverable,
                data: [
                    "metric": metric,
                    "effectSize": String(effectSize),
                    "ciLower": String(ci["lower"]!),
                    "ciUpper": String(ci["upper"]!)
                ],
                tooltipContent: tooltipContent
            ))
        }
        
        // Add zoomable region
        interactions.append(InteractiveElement(
            elementId: "effect-size-plot",
            type: .zoomable,
            data: [:],
            tooltipContent: nil
        ))
        
        // Render to SVG
        let renderer = SVGRenderer()
        plot.drawGraph(renderer: renderer)
        return (renderer.svgOutput, interactions)
    }
    
    private func createInteractiveAnomalyTimeSeries(
        historicalData: [Double],
        anomalyPoint: Double,
        expectedValue: Double,
        zScore: Double
    ) throws -> (String, [InteractiveElement]) {
        var plot = Plot(title: "Time Series with Anomaly")
        plot.addAxis(axis: .left, title: "Value")
        plot.addAxis(axis: .bottom, title: "Time")
        
        var interactions: [InteractiveElement] = []
        
        // Add interactive anomaly point
        let anomalyElementId = "anomaly-point"
        interactions.append(InteractiveElement(
            elementId: anomalyElementId,
            type: .hoverable,
            data: [
                "value": String(anomalyPoint),
                "zScore": String(zScore)
            ],
            tooltipContent: """
            Anomaly Value: \(String(format: "%.2f", anomalyPoint))
            Z-Score: \(String(format: "%.2f", zScore))
            """
        ))
        
        // Add zoomable region
        interactions.append(InteractiveElement(
            elementId: "time-series-plot",
            type: .zoomable,
            data: [:],
            tooltipContent: nil
        ))
        
        // Render to SVG
        let renderer = SVGRenderer()
        plot.drawGraph(renderer: renderer)
        return (renderer.svgOutput, interactions)
    }
    
    private func createInteractiveDistributionPlot(
        historicalData: [Double],
        anomalyValue: Double
    ) throws -> (String, [InteractiveElement]) {
        var plot = Plot(title: "Value Distribution")
        plot.addAxis(axis: .left, title: "Frequency")
        plot.addAxis(axis: .bottom, title: "Value")
        
        var interactions: [InteractiveElement] = []
        
        // Add interactive histogram bars
        let histogram = Histogram(values: historicalData, binCount: 20)
        for (index, (binStart, binEnd, count)) in histogram.bins.enumerated() {
            let elementId = "bin-\(index)"
            
            interactions.append(InteractiveElement(
                elementId: elementId,
                type: .hoverable,
                data: [
                    "binStart": String(binStart),
                    "binEnd": String(binEnd),
                    "count": String(count)
                ],
                tooltipContent: """
                Range: \(String(format: "%.2f", binStart)) - \(String(format: "%.2f", binEnd))
                Count: \(count)
                """
            ))
        }
        
        // Add interactive anomaly line
        interactions.append(InteractiveElement(
            elementId: "anomaly-line",
            type: .hoverable,
            data: ["value": String(anomalyValue)],
            tooltipContent: "Anomaly Value: \(String(format: "%.2f", anomalyValue))"
        ))
        
        // Render to SVG
        let renderer = SVGRenderer()
        plot.drawGraph(renderer: renderer)
        return (renderer.svgOutput, interactions)
    }
    
    // Private helper methods
    
    private func createImprovementsBarChart(
        improvements: [String: Double],
        analysis: [String: [String: Any]]
    ) throws -> String {
        var plot = Plot(title: "Experiment Improvements")
        plot.addAxis(axis: .left, title: "Improvement (%)")
        plot.addAxis(axis: .bottom, title: "Metrics")
        
        let metrics = improvements.keys.sorted()
        let values = metrics.map { improvements[$0]! }
        
        // Add bars
        var barGraph = BarGraph(values: values)
        barGraph.labels = metrics
        
        // Color bars based on statistical significance
        barGraph.colors = metrics.map { metric in
            if let stats = analysis[metric] as? [String: Any],
               let isSignificant = stats["isSignificant"] as? Bool {
                return isSignificant ? "green" : "gray"
            }
            return "gray"
        }
        
        plot.add(barGraph)
        
        // Add legend
        plot.addLegend(labels: ["Statistically Significant", "Not Significant"])
        
        // Render to SVG
        let renderer = SVGRenderer()
        plot.drawGraph(renderer: renderer)
        return renderer.svgOutput
    }
    
    private func createEffectSizePlot(
        analysis: [String: [String: Any]]
    ) throws -> String {
        var plot = Plot(title: "Effect Sizes")
        plot.addAxis(axis: .left, title: "Effect Size (Cohen's d)")
        plot.addAxis(axis: .bottom, title: "Metrics")
        
        let metrics = analysis.keys.sorted()
        let effectSizes = metrics.compactMap { metric -> Double? in
            guard let stats = analysis[metric] as? [String: Any],
                  let effectSize = stats["effectSize"] as? Double else {
                return nil
            }
            return effectSize
        }
        
        // Add scatter plot with error bars
        var scatter = ScatterPlot(
            x: Array(0..<metrics.count).map(Double.init),
            y: effectSizes
        )
        
        // Add confidence intervals as error bars
        for (i, metric) in metrics.enumerated() {
            if let stats = analysis[metric] as? [String: Any],
               let ci = stats["confidenceInterval"] as? [String: Double] {
                scatter.addErrorBar(
                    x: Double(i),
                    yLow: ci["lower"]!,
                    yHigh: ci["upper"]!
                )
            }
        }
        
        plot.add(scatter)
        
        // Render to SVG
        let renderer = SVGRenderer()
        plot.drawGraph(renderer: renderer)
        return renderer.svgOutput
    }
    
    private func createAnomalyTimeSeries(
        historicalData: [Double],
        anomalyPoint: Double,
        expectedValue: Double,
        zScore: Double
    ) throws -> String {
        var plot = Plot(title: "Time Series with Anomaly")
        plot.addAxis(axis: .left, title: "Value")
        plot.addAxis(axis: .bottom, title: "Time")
        
        // Plot historical data
        var timeSeries = LinePlot(
            x: Array(0..<historicalData.count).map(Double.init),
            y: historicalData
        )
        plot.add(timeSeries)
        
        // Add anomaly point
        var anomalyMarker = ScatterPlot(
            x: [Double(historicalData.count)],
            y: [anomalyPoint]
        )
        anomalyMarker.color = "red"
        plot.add(anomalyMarker)
        
        // Add expected value line
        var expectedLine = LinePlot(
            x: [0, Double(historicalData.count)],
            y: [expectedValue, expectedValue]
        )
        expectedLine.color = "green"
        expectedLine.style = .dashed
        plot.add(expectedLine)
        
        // Render to SVG
        let renderer = SVGRenderer()
        plot.drawGraph(renderer: renderer)
        return renderer.svgOutput
    }
    
    private func createDistributionPlot(
        historicalData: [Double],
        anomalyValue: Double
    ) throws -> String {
        var plot = Plot(title: "Value Distribution")
        plot.addAxis(axis: .left, title: "Frequency")
        plot.addAxis(axis: .bottom, title: "Value")
        
        // Create histogram
        let histogram = Histogram(values: historicalData, binCount: 20)
        plot.add(histogram)
        
        // Add vertical line for anomaly value
        var anomalyLine = LinePlot(
            x: [anomalyValue, anomalyValue],
            y: [0, histogram.maxFrequency]
        )
        anomalyLine.color = "red"
        plot.add(anomalyLine)
        
        // Render to SVG
        let renderer = SVGRenderer()
        plot.drawGraph(renderer: renderer)
        return renderer.svgOutput
    }
    
    private func combineVisualizations(_ svgs: [String]) -> String {
        // Combine multiple SVGs into a single visualization
        // This is a simplified version - in practice, you'd want to properly layout the SVGs
        return svgs.joined(separator: "\n")
    }
    
    private func createVisualizationDescription(results: [String: Any]) -> String {
        guard let improvements = results["improvements"] as? [String: Double],
              let analysis = results["statisticalAnalysis"] as? [String: [String: Any]] else {
            return "Visualization of experiment results"
        }
        
        var description = "This visualization shows:\n"
        description += "1. Bar chart of improvements by metric\n"
        description += "2. Effect sizes with confidence intervals\n\n"
        
        description += "Key findings:\n"
        for (metric, improvement) in improvements {
            let sign = improvement >= 0 ? "+" : ""
            description += "• \(metric): \(sign)\(String(format: "%.1f", improvement))%"
            
            if let stats = analysis[metric] as? [String: Any] {
                if let isSignificant = stats["isSignificant"] as? Bool,
                   isSignificant {
                    description += " (statistically significant)"
                }
                if let effectSize = stats["effectSize"] as? Double {
                    description += " (effect size: \(String(format: "%.2f", effectSize)))"
                }
            }
            description += "\n"
        }
        
        return description
    }
    
    private func createAnomalyDescription(anomaly: AnomalyDetection) -> String {
        return """
        Visualization of anomaly detected in \(anomaly.metric):
        1. Time series plot showing historical values and the anomaly point
        2. Distribution plot showing the position of the anomaly relative to normal values
        
        Details:
        • Detected value: \(String(format: "%.2f", anomaly.actualValue))
        • Expected value: \(String(format: "%.2f", anomaly.expectedValue))
        • Z-score: \(String(format: "%.2f", anomaly.zScore))
        • Timestamp: \(anomaly.timestamp)
        """
    }
} 