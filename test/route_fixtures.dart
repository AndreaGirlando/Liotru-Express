// Synthetic directions, short workings and a circular route, not AMTS data.
const routeFixture = {
  'stops': 'stop_id,stop_code,stop_name\nA,001,Milo Test\nB,002,Milo Test\nC,003,Policlinico Test\nD,004,Cittadella Test\n',
  'routes': 'route_id,route_short_name,route_long_name\nR1,A-MS,Metro Shuttle Test\nR2,156,Centro Test\nR3,43%_,Speciale Test\n',
  'trips': 'route_id,service_id,trip_id,direction_id\nR1,DAILY,T1,0\nR1,EXTRA,T2,0\nR1,DAILY,RETURN,1\nR1,DAILY,SHORT,0\nR1,DAILY,LOOP,0\nR2,DAILY,OTHER,0\n',
  'stop_times': 'trip_id,arrival_time,departure_time,stop_id,stop_sequence\nT1,10:00:00,10:00:00,A,1\nT1,,,B,2\nT1,10:20:00,10:20:00,C,3\nT2,11:00:00,11:00:00,A,1\nT2,,,B,2\nT2,11:20:00,11:20:00,C,3\nRETURN,12:00:00,12:00:00,C,1\nRETURN,12:10:00,12:10:00,B,2\nRETURN,12:20:00,12:20:00,A,3\nSHORT,13:00:00,13:00:00,A,1\nSHORT,13:10:00,13:10:00,C,2\nLOOP,14:00:00,14:00:00,A,1\nLOOP,14:10:00,14:10:00,B,2\nLOOP,14:20:00,14:20:00,A,3\nOTHER,15:00:00,15:00:00,B,1\nOTHER,15:10:00,15:10:00,D,2\n',
};

