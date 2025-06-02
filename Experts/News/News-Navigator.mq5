//+------------------------------------------------------------------+
//|                                               News-Navigator.mq5 |
//|                                          Copyright 2024,JBlanked |
//|                                   https://www.jblanked.com/easy/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024-2025,JBlanked"
#property link      "https://www.jblanked.com/easy/"
#property version   "2.14"
#property strict

#property description "Last Updated: June 2nd, 2025.\n\nDescription of fields below\r\n"
#property description "Trade Type: News Rampage-Settings trade less and have less drawdown. News-Ravager Settings trade almost every day but have more drawdown.\r\n"
#property description "Divide Risk by X: It will divide the risk by the input therefore lowering the risk altogether.\r\n"
#property description "Allow Auto-Updates: Select true to allow the Navigator to update itself."
#property description "Only put the News-Navigator on one chart."

#include <news-navigator.mqh>                   
CNavigator *navi;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   navi = new CNavigator();
   bool timerSet = EventSetTimer(1);
//---
   while(!timerSet)
   {
      timerSet = EventSetTimer(1);
      Sleep(1);
   }
   return navi.init();
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   navi.onDeInit(reason);
//---
   if(CheckPointer(navi) == POINTER_DYNAMIC)
   {
      delete navi;
      navi = NULL;
   }
}
//+------------------------------------------------------------------+
//| Expert onClick function                                          |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   navi.onChartDownload(id, lparam, dparam, sparam);
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   navi.run();
}
//+------------------------------------------------------------------+
