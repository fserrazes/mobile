//
//  DashboardSubView.swift
//  StairStepperMaster
//
//  Created by Saamer Mansoor on 6/16/22.
//

import SwiftUI
import HealthKit

struct DashboardSubView: View {
    @AppStorage("SyncTime") var SyncTime:String = "just now"
    @AppStorage("FlightsClimbedArray") var flightsClimbedArray:[Double] = [4,2,5,6,7,2,4]
    @AppStorage("VO2Max") var vo2Max:Double = 0
    @AppStorage("FlightsClimbed") var flightsClimbed:Double = 0

    var body: some View {
        ScrollView{
            PullToRefresh(coordinateSpaceName: "pullToRefresh") {
                // do your stuff when pulled
                print("Pulling")
                fetchHealthData()
            }
#if canImport(Charts)
            if #available(iOS 16.0, *) {
                FlightsChartTileView()
            } else{
                FlightsTileView()
            }
#else
            FlightsTileView()
#endif
            LeadersTileView()
            AchievementTileView()
            VO2MaxTileView()
            MachineTileView()
            
        }
        .coordinateSpace(name: "pullToRefresh")
    }
    
    func fetchHealthData()
    {
        let HKStore = HKHealthStore()
        
        if HKHealthStore.isHealthDataAvailable()
        {
            let readData = Set([
                HKObjectType.quantityType(forIdentifier: .heartRate)!,
                HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
                //                HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
                HKObjectType.quantityType(forIdentifier: .stepCount)!,
                HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
                HKObjectType.quantityType(forIdentifier: .vo2Max)!,
                //                HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage)!,
                HKObjectType.quantityType(forIdentifier: .stairAscentSpeed)!,
                HKObjectType.quantityType(forIdentifier: .stairDescentSpeed)!,
                HKObjectType.categoryType(forIdentifier: .highHeartRateEvent)!])
            let writeData = Set([
                HKObjectType.quantityType(forIdentifier: .stepCount)!,
                HKObjectType.quantityType(forIdentifier: .flightsClimbed)!])
            HKStore.requestAuthorization(toShare: writeData, read: readData) {(success, error) in
                if success
                {
                    let cal = NSCalendar.current
                    var anchorComps = cal.dateComponents([.day, .month, .year, .weekday], from: NSDate() as Date)
                    let offset = (5 + anchorComps.weekday! - 2) % 5
                    let endDate = Date()
                    
                    anchorComps.day! -= offset
                    anchorComps.hour = 1
                    
                    guard let anchorDate = Calendar.current.date(from: anchorComps)
                    else
                    {
                        fatalError("Can't get a valid date from the achor. You fucked something up!")
                    }
                    
                    guard let startDate = cal.date(byAdding: .day, value: -7, to: endDate)
                    else
                    {
                        fatalError("Can't generate a startDate! :-/")
                    }
                    let interval = NSDateComponents()
                    interval.hour = 24
                    
                    guard let quantityType2 = HKObjectType.quantityType(forIdentifier: .flightsClimbed)
                    else{
                        fatalError("Can't get quantityType forIdentifier: .flightsClimbed!")
                    }
                    guard let quantityType = HKObjectType.quantityType(forIdentifier: .vo2Max)
                    else
                    {
                        fatalError("Can't get quantityType forIdentifier: .vo2Max!")
                    }
                    let HKquery = HKStatisticsCollectionQuery(quantityType: quantityType, quantitySamplePredicate: nil, options: .discreteAverage, anchorDate: anchorDate, intervalComponents: interval as DateComponents)
                    let HKFlightsQuery = HKStatisticsCollectionQuery(quantityType: quantityType2, quantitySamplePredicate: nil, options: .cumulativeSum, anchorDate: anchorDate, intervalComponents: interval as DateComponents)
                    var oldFlights = 0.0
                    HKFlightsQuery.initialResultsHandler =
                    {
                        query, results, error in
                        guard let statsCollection = results
                        else
                        {
                            fatalError("Unable to get results! Reason: \(String(describing: error?.localizedDescription))")
                        }
                        oldFlights = flightsClimbed
                        flightsClimbed = 0
                        
                        flightsClimbedArray.removeAll()
                        statsCollection.enumerateStatistics(from: startDate, to: endDate)
                        {
                            statistics, stop in
                            if let quantity = statistics.sumQuantity()
                            {
                                let date = statistics.startDate
                                let val = quantity.doubleValue(for: HKUnit(from: "count"))
                                flightsClimbedArray.append(val)
                                flightsClimbed = val + flightsClimbed
//                                self.isActive = true
                            }

                        }
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "MMM d, hh:mm a"
                        SyncTime = dateFormatter.string(from: endDate)
                    }
                    HKStore.execute(HKFlightsQuery)
                    
                    HKquery.initialResultsHandler =
                    {
                        query, results, error in
                        guard let statsCollection = results
                        else
                        {
                            fatalError("Unable to get results! Reason: \(String(describing: error?.localizedDescription))")
                        }
                        
                        statsCollection.enumerateStatistics(from: startDate, to: endDate)
                        {
                            statistics, stop in
                            if let quantity = statistics.averageQuantity()
                            {
                                let date = statistics.startDate
                                let val = quantity.doubleValue(for: HKUnit(from: "mL/min·kg"))
                                vo2Max = val
//                                self.isActive = true
                            }
                        }
                        
                    }
                    HKStore.execute(HKquery)
                }
                else
                {
                    print("Unauthorized!")
                }
            }
            HKStore.enableBackgroundDelivery(for: HKObjectType.quantityType(forIdentifier: .flightsClimbed)!, frequency: .immediate) { success, error in
                if let error = error {
                    print(error.localizedDescription)
                }
            }
            
        }
        else
        {
            print("ERROR: Unable to fetch data!")
        }
    }
}

struct DashboardSubView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardSubView()
    }
}
