﻿/*
==========================================================================
This file is part of Briefing Room for DCS World, a mission
generator for DCS World, by @akaAgar (https://github.com/akaAgar/briefing-room-for-dcs)

Briefing Room for DCS World is free software: you can redistribute it
and/or modify it under the terms of the GNU General Public License
as published by the Free Software Foundation, either version 3 of
the License, or (at your option) any later version.

Briefing Room for DCS World is distributed in the hope that it will
be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Briefing Room for DCS World. If not, see https://www.gnu.org/licenses/
==========================================================================
*/

using BriefingRoom4DCS.Data;
using BriefingRoom4DCS.Template;
using System;
using System.Collections.Generic;
using System.Linq;

namespace BriefingRoom4DCS.Generator
{
    /// <summary>
    /// Selects random spawn points and airbase parking spots from a theater.
    /// </summary>
    internal class UnitMakerSpawnPointSelector : IDisposable
    {
        /// <summary>
        /// How many times should GetRandomSpawnPoint() expand its search radius when no nodes are found?
        /// </summary>
        private const int MAX_RADIUS_SEARCH_ITERATIONS = 32;

        /// <summary>
        /// List of available airbase parking spots for each airbase.
        /// </summary>
        private readonly Dictionary<int, List<DBEntryAirbaseParkingSpot>> AirbaseParkingSpots;

        /// <summary>
        /// List of available spawn points.
        /// </summary>
        private readonly List<DBEntryTheaterOldSpawnPoint> OldSpawnPoints;

        private readonly List<DBEntryTheaterSpawnPoint> SpawnPoints;

        /// <summary>
        /// Theater database entry
        /// </summary>
        private readonly DBEntryTheater TheaterDB;

        private readonly bool UseShapeSpawningSystem;

        /// <summary>
        /// Constructor.
        /// </summary>
        /// <param name="theaterDB">Theater database entry to use</param>
        internal UnitMakerSpawnPointSelector(DBEntryTheater theaterDB, bool useShapeSpawningSystem)
        {
            TheaterDB = theaterDB;
            UseShapeSpawningSystem = useShapeSpawningSystem;

            AirbaseParkingSpots = new Dictionary<int, List<DBEntryAirbaseParkingSpot>>();
            SpawnPoints = new List<DBEntryTheaterSpawnPoint>();
            OldSpawnPoints = new List<DBEntryTheaterOldSpawnPoint>();

            Clear();
        }

        /// <summary>
        /// Returns a free parking spot for the given airbase.
        /// </summary>
        /// <param name="airbaseID">Internal ID of the airbase in DCS World</param>
        /// <param name="parkingSpotCoordinates">Coordinates of the selected parking spot</param>
        /// <param name="lastSpotCoordinates">Coordinates of the last aircraft spot picked, if any. Will try to pick a spot near this one.</param>
        /// <param name="requiresOpenAirParking">Should the aircraft be spawned on an opened parking spot (not in a hangar)?</param>
        /// <returns>A parking spot ID, or -1 if none found or if airbase doesn't exist</returns>
        internal int GetFreeParkingSpot(int airbaseID, out Coordinates parkingSpotCoordinates, Coordinates? lastSpotCoordinates = null, bool requiresOpenAirParking = false)
        {
            parkingSpotCoordinates = new Coordinates();
            if (!AirbaseParkingSpots.ContainsKey(airbaseID) || (AirbaseParkingSpots[airbaseID].Count == 0)) return -1;
            DBEntryAirbase[] airbaseDB = (from DBEntryAirbase ab in TheaterDB.GetAirbases() where ab.DCSID == airbaseID select ab).ToArray();
            if (airbaseDB.Length == 0) return -1; // No airbase with proper DCSID
            DBEntryAirbaseParkingSpot? parkingSpot = null;
            if (lastSpotCoordinates != null) //find nearest spot distance wise in attempt to cluster
                parkingSpot = AirbaseParkingSpots[airbaseID].FindAll(x => (!requiresOpenAirParking || x.ParkingType != ParkingSpotType.HardenedAirShelter))
                    .ToList()
                    .Aggregate((acc, x) => acc.Coordinates.GetDistanceFrom(lastSpotCoordinates.Value) > x.Coordinates.GetDistanceFrom(lastSpotCoordinates.Value) && x.Coordinates.GetDistanceFrom(lastSpotCoordinates.Value) != 0 ? x : acc);
            else
                parkingSpot = Toolbox.RandomFrom(AirbaseParkingSpots[airbaseID]);
            AirbaseParkingSpots[airbaseID].Remove(parkingSpot.Value);
            parkingSpotCoordinates = parkingSpot.Value.Coordinates;
            return parkingSpot.Value.DCSID;
        }

        internal void Clear()
        {
            AirbaseParkingSpots.Clear();
            SpawnPoints.Clear();
            if(TheaterDB.SpawnPoints is not null)
                SpawnPoints.AddRange(TheaterDB.SpawnPoints);

            OldSpawnPoints.Clear();
            OldSpawnPoints.AddRange(TheaterDB.OldSpawnPoints);

            foreach (DBEntryAirbase airbase in TheaterDB.GetAirbases())
            {
                if (airbase.ParkingSpots.Length < 1) continue;
                if (AirbaseParkingSpots.ContainsKey(airbase.DCSID)) continue;
                AirbaseParkingSpots.Add(airbase.DCSID, airbase.ParkingSpots.ToList());
            }
        }

        /// <summary>
        /// Gets a random spawn point around a given point.
        /// </summary>
        /// <param name="validTypes">Valid spawn point types</param>
        /// <param name="distanceOrigin1">Origin point distance must be computed from</param>
        /// <param name="distanceFrom1">Min/max distance from origin point, in nautical miles</param>
        /// <param name="distanceOrigin2">Second origin point distance must be computed from</param>
        /// <param name="distanceFrom2">Min/max distance from second origin point, in nautical miles</param>
        /// <param name="coalition">Which coalition should the spawn point belong to?</param>
        /// <returns>A spawn point, or null if none found matching the provided criteria</returns>
        internal Coordinates? GetRandomSpawnPoint(
            SpawnPointType[] validTypes,
            Coordinates distanceOrigin1, MinMaxD distanceFrom1,
            Coordinates? distanceOrigin2 = null, MinMaxD? distanceFrom2 = null,
            Coalition? coalition = null)
        {

            if (TheaterDB.ShapeSpawnSystem && UseShapeSpawningSystem)
                return GetRandomSpawnPointShapeSystem(
                    validTypes,
                    distanceOrigin1, distanceFrom1,
                    distanceOrigin2, distanceFrom2,
                    coalition
                    );

            // Select all spoint points
            IEnumerable<DBEntryTheaterOldSpawnPoint> validSP = from DBEntryTheaterOldSpawnPoint pt in OldSpawnPoints select pt;

            if (!validTypes.Contains(SpawnPointType.Air)) // Remove spawn points of invalid types
                validSP = (from DBEntryTheaterOldSpawnPoint pt in validSP where validTypes.Contains(pt.PointType) select pt);

            if (coalition.HasValue) // Select spawn points belonging to the proper coalition
            {
                IEnumerable<DBEntryTheaterOldSpawnPoint> coalitionValidSP =
                    coalitionValidSP = (from DBEntryTheaterOldSpawnPoint sp in validSP where sp.Coalition == coalition.Value select sp);

                // At least one spawn point found, only use SP for the preferred coalition
                if (coalitionValidSP.Count() > 0)
                    validSP = coalitionValidSP;
            }

            Coordinates?[] distanceOrigin = new Coordinates?[] { distanceOrigin1, distanceOrigin2 };
            MinMaxD?[] distanceFrom = new MinMaxD?[] { distanceFrom1, distanceFrom2 };

            for (int i = 0; i < 2; i++) // Remove spawn points too far or too close from distanceOrigin1 and distanceOrigin2
            {
                if (validSP.Count() == 0) return null;
                if (!distanceFrom[i].HasValue || !distanceOrigin[i].HasValue) continue;

                MinMaxD searchRange = distanceFrom[i].Value * Toolbox.NM_TO_METERS; // convert distance to meters

                IEnumerable<DBEntryTheaterOldSpawnPoint> validSPInRange = (from DBEntryTheaterOldSpawnPoint s in validSP select s);

                int iterationsLeft = MAX_RADIUS_SEARCH_ITERATIONS;

                do
                {
                    Coordinates origin = distanceOrigin[i].Value;

                    validSPInRange = (from DBEntryTheaterOldSpawnPoint s in validSP
                                      where searchRange.Contains(origin.GetDistanceFrom(s.Coordinates))
                                      select s);
                    searchRange = new MinMaxD(searchRange.Min * 0.9, Math.Max(100, searchRange.Max * 1.1));
                    iterationsLeft--;
                } while ((validSPInRange.Count() == 0) && (iterationsLeft > 0));

                validSP = (from DBEntryTheaterOldSpawnPoint s in validSPInRange select s);
            }

            if (validSP.Count() == 0) return null;

            DBEntryTheaterOldSpawnPoint selectedSpawnPoint = Toolbox.RandomFrom(validSP.ToArray());
            OldSpawnPoints.Remove(selectedSpawnPoint); // Remove spawn point so it won't be used again
            return selectedSpawnPoint.Coordinates;
        }

        private Coordinates? GetRandomSpawnPointShapeSystem(
            SpawnPointType[] validTypes,
            Coordinates distanceOrigin1, MinMaxD distanceFrom1,
            Coordinates? distanceOrigin2 = null, MinMaxD? distanceFrom2 = null,
            Coalition? coalition = null)
        {
            if (validTypes.Contains(SpawnPointType.Air) || validTypes.Contains(SpawnPointType.Sea))
                return GetAirOrSeaCoordinates(validTypes, distanceOrigin1, distanceFrom1, distanceOrigin2, distanceFrom2, coalition);
            return GetLandCoordinates(validTypes, distanceOrigin1, distanceFrom1, distanceOrigin2, distanceFrom2, coalition);
        }

        private Coordinates? GetLandCoordinates(
            SpawnPointType[] validTypes,
            Coordinates distanceOrigin1, MinMaxD distanceFrom1,
            Coordinates? distanceOrigin2 = null, MinMaxD? distanceFrom2 = null,
            Coalition? coalition = null
        )
        {
            var validSP = (from DBEntryTheaterSpawnPoint pt in SpawnPoints where validTypes.Contains(pt.PointType) select pt);
            Coordinates?[] distanceOrigin = new Coordinates?[] { distanceOrigin1, distanceOrigin2 };
            MinMaxD?[] distanceFrom = new MinMaxD?[] { distanceFrom1, distanceFrom2 };

            for (int i = 0; i < 2; i++) // Remove spawn points too far or too close from distanceOrigin1 and distanceOrigin2
            {
                if (validSP.Count() == 0) return null;
                if (!distanceFrom[i].HasValue || !distanceOrigin[i].HasValue) continue;

                var searchRange = distanceFrom[i].Value * Toolbox.NM_TO_METERS; // convert distance to meters

                IEnumerable<DBEntryTheaterSpawnPoint> validSPInRange = (from DBEntryTheaterSpawnPoint s in validSP select s);

                int iterationsLeft = MAX_RADIUS_SEARCH_ITERATIONS;

                do
                {
                    Coordinates origin = distanceOrigin[i].Value;

                    validSPInRange = (from DBEntryTheaterSpawnPoint s in validSP
                                      where searchRange.Contains(origin.GetDistanceFrom(s.Coordinates)) && CheckNotInHostileCoords(s.Coordinates, coalition)
                                      select s);
                    searchRange = new MinMaxD(searchRange.Min * 0.9, Math.Max(100, searchRange.Max * 1.1));
                    validSP = (from DBEntryTheaterSpawnPoint s in validSPInRange select s);
                    iterationsLeft--;
                } while ((validSPInRange.Count() == 0) && (iterationsLeft > 0));
            }

            if (validSP.Count() == 0) return null;
            DBEntryTheaterSpawnPoint selectedSpawnPoint = Toolbox.RandomFrom(validSP.ToArray());
            SpawnPoints.Remove(selectedSpawnPoint); // Remove spawn point so it won't be used again
            return selectedSpawnPoint.Coordinates;
        }

        private Coordinates? GetAirOrSeaCoordinates(
            SpawnPointType[] validTypes,
            Coordinates distanceOrigin1, MinMaxD distanceFrom1,
            Coordinates? distanceOrigin2 = null, MinMaxD? distanceFrom2 = null,
            Coalition? coalition = null)
        {
            var searchRange = distanceFrom1 * Toolbox.NM_TO_METERS;
            var iterations = 0;
            do
            {   
                var coordOptionsLinq = Enumerable.Range(0, 50)
                    .Select(x => Coordinates.CreateRandom(distanceOrigin1, searchRange))
                    .Where(x => CheckNotInHostileCoords(x, coalition));

                if (distanceOrigin2.HasValue && distanceFrom2.HasValue)
                {   
                    coordOptionsLinq = coordOptionsLinq.Where(x => distanceFrom2.Value.Contains(distanceOrigin2.Value.GetDistanceFrom(x)));
                }
                if (validTypes.First() == SpawnPointType.Sea) //sea position
                    coordOptionsLinq = coordOptionsLinq.Where(x => ShapeManager.IsPosValid(x, TheaterDB.WaterCoordinates, TheaterDB.WaterExclusionCoordinates));
                var coordOptions = coordOptionsLinq.ToArray();
                if(coordOptionsLinq.Count() > 0)
                    return Toolbox.RandomFrom(coordOptions);

                searchRange = new MinMaxD(searchRange.Min * 0.9, searchRange.Max * 1.1);
                iterations++;
            } while (iterations < MAX_RADIUS_SEARCH_ITERATIONS);
            return null;
        }


        internal static Coalition? GetSpawnPointCoalition(MissionTemplate template, Side side)
        {
            // No countries spawning restriction
            if (template.OptionsMission.Contains(MissionOption.SpawnAnywhere)) return null;

            Coalition coalition = side == Side.Ally ? template.ContextPlayerCoalition : template.ContextPlayerCoalition.GetEnemy();

            if (template.OptionsMission.Contains(MissionOption.InvertCountriesCoalitions))
                coalition = coalition.GetEnemy();

            return coalition;
        }

        private bool CheckNotInHostileCoords(Coordinates coordinates, Coalition? coalition = null)
        {
            if (!coalition.HasValue)
                return true;
            if (coalition == Coalition.Blue)
                return !ShapeManager.IsPosValid(coordinates, TheaterDB.RedCoordinates);
            return !ShapeManager.IsPosValid(coordinates, TheaterDB.BlueCoordinates);
        }

        /// <summary>
        /// <see cref="IDisposable"/> implementation.
        /// </summary>
        public void Dispose() { }
    }
}
