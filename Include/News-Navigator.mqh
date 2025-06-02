//+------------------------------------------------------------------+
//|                                               News-Navigator.mqh |
//|                                 Copyright 2024-2025,JBlanked LLC |
//|                          https://www.jblanked.com/trading-tools/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024-2025,JBlanked LLC"
#property link      "https://www.jblanked.com/trading-tools/"
#property strict

#define BASE_URL "https://www.jblanked.com/"
#define API_URL BASE_URL "news/news-navigator/"
#define ZIP_FILE_NAME "News-Navigator.zip"
#define DOWNLAOD_URL BASE_URL "trading-tools/download/tools/" + ZIP_FILE_NAME

#include <easy-button.mqh>
#include <premium-button.mqh>
#include <download.mqh>
#include <countdown.mqh>
#include <jb-cache.mqh>
#include <jb-requests.mqh>
#include <jb-json.mqh>
#include <jb-backtest.mqh>
#include <panel-draw.mqh>

enum enum_premium
{
   all = 0, // All Settings
   rav = 1, // News-Ravager Settings
   easy_button = 2, // News-Rampage Settings
};

input enum_premium   trade_type  = easy_button; // Trade Type
input double         div_risk_by = 3;           // Divide Risk by X (3 = Live, 20 = Funded)
input long           inpMagicc   = 823141;      // Magic Number
input bool           autoUpdate  = true;        // Allow Auto-Updates?
input double         inpMaxDD    = 50.0;        // Max Daily Loss %

const string Permissions2[] = {"vip-pro", "premium-button", "news-navigator"};

// ---- global variables
bool ravager_is_active;
datetime thisDate;
string thisDatee;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CNavigator
{
private:
   CPanelDraw        *draw;
   CLabel            nextEvent, lastUpdated, lastPing, statusLabel, profitLabel;
   JSON              json;
   CCache            *cache;
   CJAVal            EasyButtonAPIPage;
   CDownload         d;
   CCountdown        cn;
   int               Start;
   string            last_updated;
   datetime          start_start_time;
   int               start_start_iteration;
   bool              showNews;
   datetime          last_time;
   datetime          current_5th;
   datetime          current_3rd;
   CJAVal            old_json;
   datetime          next_time;
   string            user_key;
   datetime          lastHour;
   string            lastCom, comm;
   string            nextDatee;
   datetime          nextDate;
   CJBTrade          jb;
   CTime             tme;
public:
   bool              isTester(void)
   {
      return bool(MQLInfoInteger(MQL_OPTIMIZATION)) || bool(MQLInfoInteger(MQL_TESTER));
   }

   int               init()
   {

      // ask if want to backtest, if not continue
      if(!this.isTester())
      {
         testerInputs naviInputs;
         //---
#ifdef __MQL5__
         naviInputs.expertName    = "News-Navigator.ex5";
#else
         naviInputs.expertName    = "News-Navigator.ex4";
#endif
         naviInputs.symbol        = _Symbol;
         naviInputs.currency      = AccountInfoString(ACCOUNT_CURRENCY);
         naviInputs.timeFrame     = PERIOD_M30;
         naviInputs.fromDate      = D'2024.01.01';
         naviInputs.toDate        = (datetime)TimeToString(TimeCurrent(), TIME_DATE);
         naviInputs.leverage      = AccountInfoInteger(ACCOUNT_LEVERAGE);
         naviInputs.executionMode = 27;
         naviInputs.visual        = 0;
         naviInputs.optimization  = 0;
         naviInputs.model         = 0;
         naviInputs.forwardMode   = 0;
         naviInputs.profitInPips  = 0;
         naviInputs.deposit       = AccountInfoDouble(ACCOUNT_BALANCE);
         naviInputs.optimizationCriterion = 3;
         //---
         CBacktest test(naviInputs);
         //---
         test.addSetting("apikey", apikey);
         test.addSetting("trade_type", (int)trade_type);
         test.addSetting("div_risk_by", test.doubleToString(div_risk_by, 1));
         test.addSetting("inpMagicc", IntegerToString(inpMagicc));
         test.addSetting("autoUpdate", autoUpdate);
         test.addSetting("inpMaxDD", test.doubleToString(inpMaxDD, 1));

         if(test.ask())
         {
            ExpertRemove();
         }
      }

      if(!this.isTester())
      {

         const int cHeight = int(ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS));

         if(cHeight <= 300)
         {
            Alert("Your chart height '" + string(cHeight) + "' is less than the required minimum '300'");
         }

         if(div_risk_by <= 1)
         {
            Alert("You are using too much risk!! Please lower it to 2 or 3");
         }

         draw = new CPanelDraw("News-Navigator", 0, cHeight - 275, (int)(ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) / 2), cHeight, 0);
         draw.CreateLabel(nextEvent, "nextEvent", "Upcoming Event:  ", clrCyan, 11, 10, 10, 1, 1);
         draw.CreateLabel(lastUpdated, "lastUpdated", "Last Updated:   " + last_updated, clrBeige, 11, 10, 40, 1, 1);
         draw.CreateLabel(lastPing, "lastPing", "Last Ping:      ", clrCyan, 11, 10, 70, 1, 1);
         draw.CreateLabel(statusLabel, "status", "Status:         Initializing", clrBeige, 11, 10, 100, 1, 1);
         draw.CreateLabel(profitLabel, "profit", "Total Profit:   " + DoubleToString(HistoryProfit(), 4) + "%", clrCyan, 11, 10, 130, 1, 1);
         draw.CreateButton("downloadNewsNavigator", "Download", clrCyan, clrGray, 11, 175, draw.Height() - 10, 475, 170);
         draw.CreatePanel();
      }
      else
      {
         Print("Loading API and checking permissions...");
      }

      Start = INIT_FAILED;

      vip.headers = CHeader("News-Navigator");
#ifdef __MQL5__
      vip.headers.orderCount     = PositionsTotal();
#else
      vip.headers.orderCount     = OrdersTotal();
#endif
      vip.headers.currentProfit  = currentProfit();
      vip.headers.totalProfit    = HistoryProfit();
      vip.headers.todayProfit    = TodayProfit();
      vip.headers.weekProfit     = WeekProfit();
      vip.headers.monthProfit    = MonthProfit();

      vip.Append(vip.account_numebrs, 8308488);

      if(!this.isTester())
      {
         statusLabel.Text("Status:         Authenticating");
      }
      cache = new CCache("News-Navigator");
      if(vip.CheckGroup(Permissions2, false))
      {

         if(!this.isTester())
         {
            statusLabel.Text("Status:         Fetching Data");

            if(div_risk_by != 3 && div_risk_by != 20)
            {
               ::Alert("Your are not using the default settings...");
            }

         }
         else
         {
            Print("Authenticated! Fetching Data..");
         }

         api.key = apikey;
         api.url = API_URL;

         if(this.isTester() && cache.findCJAVal("news_navigator_api_data"))
         {
            EasyButtonAPIPage = cache.getCJAVal("news_navigator_api_data");
            switch(trade_type)
            {
            case all:
               if(easy.Start(EasyButtonAPIPage) != -1 && premium.Start(EasyButtonAPIPage) != -1)
                  Start = INIT_SUCCEEDED;
               else
               {
                  Alert(AccountInfoString(ACCOUNT_NAME) + " is not authenticated.");
                  return INIT_FAILED;
               }
               break;

            case rav:
               Start = premium.Start(EasyButtonAPIPage);
               break;
            case easy_button:
               Start = easy.Start(EasyButtonAPIPage);
               break;
            }
         }
         else
         {
            if(api.GET(EasyButtonAPIPage, vip.headers.toStr(), BASE_URL, true))
            {
               if(!this.isTester())
               {
                  statusLabel.Text("Status:         Syncing Data");
               }
               else
               {
                  Print("Data received. Syncing Data..");
                  cache.setCJAVal("news_navigator_api_data", EasyButtonAPIPage, 1800);
               }
               switch(trade_type)
               {
               case all:
                  if(easy.Start(EasyButtonAPIPage) != -1 && premium.Start(EasyButtonAPIPage) != -1)
                     Start = INIT_SUCCEEDED;
                  else
                  {
                     Alert(AccountInfoString(ACCOUNT_NAME) + " is not authenticated.");
                     return INIT_FAILED;
                  }
                  break;

               case rav:
                  Start = premium.Start(EasyButtonAPIPage);
                  break;
               case easy_button:
                  Start = easy.Start(EasyButtonAPIPage);
                  break;
               }

            }
         }
      }

      if(Start == INIT_SUCCEEDED && !this.isTester())
      {
         Print(AccountInfoString(ACCOUNT_NAME) + " is authenticated.");
#ifdef __MQL5__
         Print(
            "\r\nLast Updated: June 2nd, 2025.\r\n\r\nDescription of fields below:\r\n\r\n"
            "Trade Type: News Rampage Settings trade less and have less drawdown. News Ravager Settings trade almost every day but have more drawdown.\r\n"
            "Divide Risk by X: It will divide the risk by the input therefore lowering the risk altogether.\r\n"
            "Allow Auto-Updates: Select true you want bot to update itself when there is a new update available.\r\n"
            "Only put the News-Navigator on one chart.\r\n"
         );
         next_time = tme.changeTime(TimeCurrent(), 12, ENUM_HOUR);
#else
         Print("");
         Print("Last Updated: June 2nd, 2025.");
         Print("");
         Print("Description of fields above:");
         Print("Trade Type: News Rampage Settings trade less and have less drawdown. News Ravager Settings trade almost every day but have more drawdown.");
         Print("Divide Risk by X: It will divide the risk by the input therefore lowering the risk altogether.");
         Print("Allow Auto-Updates: Select true you want bot to update itself when there is a new update available.");
         Print("Only put the News-Navigator on one chart.");
         Print("");
         next_time = tme.changeTime(TimeCurrent(), 12, ENUM_HOUR);
#endif

         last_updated = djangoTimetoDate(EasyButtonAPIPage["Last Updated"].ToStr());
         lastUpdated.Text("Last Updated:   " + last_updated);
         lastPing.Text("Last Ping:      " + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS));
         statusLabel.Text("Status:         Authenticated");
         cache.set("last_updated", last_updated, 1500);
      }

      return Start;
   }
   void              onDeInit(const int reason)
   {
      if(!this.isTester())
      {
         EventKillTimer();
      }
      jb.deletePointer(cache);
      if(draw != NULL)
      {
         draw.Destroy(reason);
         delete draw;
         draw = NULL;
      }
   }

   string            djangoTimetoDate(const string djangoTime)
   {
      string newTime = djangoTime;
      StringReplace(newTime, "-", ".");
      StringReplace(newTime, "T", " ");
      StringReplace(newTime, "Z", "");
      return TimeToString(StringToTime(newTime) + (3 * PeriodSeconds(PERIOD_H1)), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
   };

   void              onChartDownload(const int id, const long &lparam, const double &dparam, const string &sparam)
   {
      draw.PanelChartEvent(id, lparam, dparam, sparam);

      if(id == CHARTEVENT_OBJECT_CLICK)
      {
         if(sparam == "downloadNewsNavigator")
         {
            Alert("Downloading the News-Navigator now...");
            if(!d.downloadAndExtract(DOWNLAOD_URL, ZIP_FILE_NAME))
            {
               Print("Failed to download.. Trying again...");
               d.downloadAndExtract(DOWNLAOD_URL, ZIP_FILE_NAME);
            }

            last_updated = djangoTimetoDate(EasyButtonAPIPage["Last Updated"].ToStr());
            cache.set("last_updated", last_updated, 1500);
            lastUpdated.Text("Last Updated:   " + last_updated);
         }

      }
   }

   void              run()
   {
#ifdef __MQL4__

      if(!this.isTester())
      {

#endif

         if(!this.isTester())
         {
            comm = thisDatee + ": " + cn.timer(thisDate);

            if(thisDatee != "" && thisDate != 0 && lastCom != comm)
            {
               lastCom = comm;
               if(thisDate > TimeCurrent())
               {
                  nextEvent.Text("Upcoming Event: " + lastCom);
               }
               else
               {
                  nextEvent.Text("Previous Event: " + lastCom);
               }
            }

            if(TimeCurrent() >= next_time)
            {
               statusLabel.Text("Status:         Authenticating");

               if(!vip.CheckGroup(Permissions2))
               {
                  Alert(AccountInfoString(ACCOUNT_NAME) + " is not authenticated..");
                  ExpertRemove();
               }
               else
               {
#ifdef __MQL5__
                  next_time = tme.changeTime(TimeCurrent(), 12, ENUM_HOUR);
#else
                  next_time = tme.changeTime(TimeCurrent(), 12, ENUM_HOUR);
#endif
                  statusLabel.Text("Status:         Authenticated");
               }
            }

            current_3rd = iTime(_Symbol, PERIOD_M1, 3); // set this to the datetime of 3 candles ago
            current_5th = iTime(_Symbol, PERIOD_M5, 0); // set this to the datetime of 5 candles ago

            if(current_3rd > current_5th && current_3rd != last_time)
            {
               statusLabel.Text("Status:         Fetching Data");
               last_time = current_3rd;
               api.key = apikey;
               api.url = API_URL;

               vip.headers.orderCount     = jb.PositionsTotal();
               vip.headers.currentProfit  = currentProfit();
               vip.headers.totalProfit    = HistoryProfit();
               vip.headers.todayProfit    = TodayProfit();
               vip.headers.weekProfit     = WeekProfit();
               vip.headers.monthProfit    = MonthProfit();

               bool got = api.GET(EasyButtonAPIPage, vip.headers.toStr(), BASE_URL, false);
               if(!got)
               {
                  int iterr = 0;
                  do
                  {
                     Sleep(1000);
                     got = api.GET(EasyButtonAPIPage, vip.headers.toStr(), BASE_URL, true);
                     iterr++;
                  }
                  while(!got && iterr < 10);
               }

               lastPing.Text("Last Ping:      " + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS));

               if(jb.PositionsTotal() < 1 && autoUpdate)
               {

                  if(last_updated != "" && last_updated != djangoTimetoDate(EasyButtonAPIPage["Last Updated"].ToStr()) && EasyButtonAPIPage["Last Updated"].ToStr() != "")
                  {

                     statusLabel.Text("Status:         Updating");
                     Alert("There is an update available for the News-Navigator! Downloading now... ");
                     SendNotification("There is an update available for the News-Navigator! Downloading now... ");


                     if(!d.downloadAndExtract(DOWNLAOD_URL, ZIP_FILE_NAME))
                     {
                        statusLabel.Text("Status:         Re-downloading");
                        Print("Error downloading.. re-downloading now...");
                        if(!d.downloadAndExtract(DOWNLAOD_URL, ZIP_FILE_NAME))
                        {
                           Alert("Failed to download... restart MetaTrader...");
                        }
                     }


                     last_updated = djangoTimetoDate(EasyButtonAPIPage["Last Updated"].ToStr());
                     cache.set("last_updated", last_updated, 1500);
                     lastUpdated.Text("Last Updated:   " + last_updated);
                     statusLabel.Text("Status:         Updated");
                  }

               }

               statusLabel.Text("Status:         Parsing Data");

               switch(trade_type)
               {
               case rav:
                  premium.SetAPI(EasyButtonAPIPage);
                  break;
               case easy_button:
                  easy.RefreshAPI(EasyButtonAPIPage);
                  break;
               case all:
                  easy.RefreshAPI(EasyButtonAPIPage);
                  premium.SetAPI(EasyButtonAPIPage);
                  break;
               }
               statusLabel.Text("Status:         Finished");

            } // end of if it's time to update (4 minutes)

            if(jb.PositionsTotal() > 0)
            {
               statusLabel.Text("Status:         Trading");
            }
            else
            {
               statusLabel.Text("Status:         Connected");
            }

            profitLabel.Text("Total Profit:   " + DoubleToString(HistoryProfit(), 4) + "%");
         } // end of if not optimization/tester

         // run Rampage and Ravager
         switch(trade_type)
         {
         case rav:
            premium.Run();
            break;
         case easy_button:
            easy.RunEasyButton();
            break;
         case all:
            easy.RunEasyButton();
            premium.Run();
            break;
         }

         // check drawdown breached
         this.monitorDD();

#ifdef __MQL4__
      } // end of if not optimization/tester
#endif

   }
#ifdef __MQL4__
   void              runMQL4()
   {

      if(this.isTester())
      {
         switch(trade_type)
         {
         case rav:
            premium.Run();
            break;
         case easy_button:
            easy.RunEasyButton();
            break;
         case all:
            easy.RunEasyButton();
            premium.Run();
            break;
         }

      }
   }
#endif
   bool              isDailyLossBreached(void)
   {
      return TodayProfit() <= -(inpMaxDD);
   }

   void              monitorDD(void)
   {
      if(this.dailyLossBreached && trade.PositionsTotal() < 1)
      {
         this.dailyLossBreached = false;
      }

      if(!this.dailyLossBreached && this.lastDay < iTime(_Symbol, PERIOD_D1, 0) && this.isDailyLossBreached())
      {
         ::Print("Daily loss breached... closing trades now.");
         jb.CloseBotTrades("JB-That Was Easy");
         jb.CloseBotTrades("That Was Easy");
         jb.CloseBotTrades("Premium Button (JBlanked.com)");
         this.dailyLossBreached = true;
         this.lastDay = iTime(_Symbol, PERIOD_D1, 0);
      }
   }
   bool              dailyLossBreached;
   datetime          lastDay;
   double            realAccountBlance()
   {
      // gets the balance from the last deposit/withdrawal
      return jb.BalanceAtLastDepositWithdrawal(0, TimeCurrent());
   }

   double            CurrentAccountBalance()
   {
      // balance at last withdraw + all profit since then (excluding open positions)
      return realAccountBlance() + AllProfit();
   }

   double            currentProfit(void)
   {
      // current profit + current account balance = equity
      return jb.percentProfit(NBotCurrentProfit() + CurrentAccountBalance(), CurrentAccountBalance());
   }
   double            HistoryProfit()
   {
      // balance = balance since last withdrawal/deposit, equity = current profit + current account balance
      return jb.percentProfit(NBotCurrentProfit() + CurrentAccountBalance(), realAccountBlance());

   }
   double            TodayProfit()
   {
      //if no withdrawal/deposit today, then use current account balance
      return jb.percentProfit(DailyProfit(), jb.BalanceAtLastDepositWithdrawal(iTime(_Symbol, PERIOD_D1, 0), TimeCurrent(), AccountInfoDouble(ACCOUNT_BALANCE)));

   }

   double            WeekProfit()
   {
      // if no balance change this week, then use the next-latest
      return jb.percentProfit(WeeklyProfit(), jb.BalanceAtLastDepositWithdrawal(iTime(_Symbol, PERIOD_W1, 0), TimeCurrent(), realAccountBlance()));

   }

   double            MonthProfit()
   {
      // if no balance change this month, then use the next-latest
      return jb.percentProfit(MonthlyProfit(), jb.BalanceAtLastDepositWithdrawal(iTime(_Symbol, PERIOD_MN1, 0), TimeCurrent(), realAccountBlance()));
   }
#ifdef __MQL5__
   //+------------------------------------------------------------------+
   double            DealProfit(const double takeProfit, double stoploss, datetime theStarttime)
   {
      double profit = 0;

      // retrieve magic number of each order in history
      if(HistorySelect(theStarttime, TimeCurrent()))   // select all history data from today
      {

         for(int i = HistoryDealsTotal(); i >= 0 ; i--)   //count
         {

            ulong ticket = HistoryDealGetTicket(i);

            profit += HistoryDealGetDouble(ticket, DEAL_SL) == stoploss &&
                      HistoryDealGetDouble(ticket, DEAL_TP) == takeProfit
                      ?
                      HistoryDealGetDouble(ticket, DEAL_PROFIT) +  HistoryDealGetDouble(ticket, DEAL_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION)
                      :
                      0;
         }
      }

      return profit;
   }
#endif

   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   double            AllProfit(void)
   {
      return
         jb.ProfitFromLastDeposit("", "That Was Easy") +
         jb.ProfitFromLastDeposit("", "Premium Button (JBlanked.com)") +
         jb.ProfitFromLastDeposit("", "JB-That Was Easy[sl]") +
         jb.ProfitFromLastDeposit("", "JB-That Was Easy");
   }
   //+------------------------------------------------------------------+

   double            DailyProfit(void)
   {
      return
         jb.HistoryProfitComment("That Was Easy", iTime(_Symbol, PERIOD_D1, 0), TimeCurrent()) +
         jb.HistoryProfitComment("Premium Button (JBlanked.com)", iTime(_Symbol, PERIOD_D1, 0), TimeCurrent()) +
         jb.HistoryProfitComment("JB-That Was Easy[sl]", iTime(_Symbol, PERIOD_D1, 0), TimeCurrent()) +
         jb.HistoryProfitComment("JB-That Was Easy", iTime(_Symbol, PERIOD_D1, 0), TimeCurrent()) +
         jb.BalanceAtLastDepositWithdrawal(iTime(_Symbol, PERIOD_D1, 0), TimeCurrent(), AccountInfoDouble(ACCOUNT_BALANCE));

   }

   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   double            WeeklyProfit(void)
   {
      return
         jb.HistoryProfitComment("That Was Easy", iTime(_Symbol, PERIOD_W1, 0), TimeCurrent()) +
         jb.HistoryProfitComment("Premium Button (JBlanked.com)", iTime(_Symbol, PERIOD_W1, 0), TimeCurrent()) +
         jb.HistoryProfitComment("JB-That Was Easy[sl]", iTime(_Symbol, PERIOD_W1, 0), TimeCurrent()) +
         jb.HistoryProfitComment("JB-That Was Easy", iTime(_Symbol, PERIOD_W1, 0), TimeCurrent()) +
         jb.BalanceAtLastDepositWithdrawal(iTime(_Symbol, PERIOD_W1, 0), TimeCurrent(), AccountInfoDouble(ACCOUNT_BALANCE));
   }

   //+------------------------------------------------------------------+
   //|                                                                  |
   //+------------------------------------------------------------------+
   double            MonthlyProfit(void)
   {
      return
         jb.HistoryProfitComment("That Was Easy", iTime(_Symbol, PERIOD_MN1, 0), TimeCurrent()) +
         jb.HistoryProfitComment("Premium Button (JBlanked.com)", iTime(_Symbol, PERIOD_MN1, 0), TimeCurrent()) +
         jb.HistoryProfitComment("JB-That Was Easy[sl]", iTime(_Symbol, PERIOD_MN1, 0), TimeCurrent()) +
         jb.HistoryProfitComment("JB-That Was Easy", iTime(_Symbol, PERIOD_MN1, 0), TimeCurrent()) +
         jb.BalanceAtLastDepositWithdrawal(iTime(_Symbol, PERIOD_MN1, 0), TimeCurrent(), AccountInfoDouble(ACCOUNT_BALANCE));
   }
};
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double            NBotCurrentProfit()
{
   double profit = 0;

#ifdef __MQL5__
   for(int i = PositionsTotal(); i >= 0; i--)   //count backwards
   {
      if(posi.SelectByIndex(i))   // select the order
      {
         const string commi = posi.Comment();

         if(commi == "JB-That Was Easy" || commi == "That Was Easy" || commi == "Premium Button (JBlanked.com)" || commi == "JB-That Was Easy[sl]")
            profit += posi.Profit() + posi.Swap() + posi.Commission();
      }
   }
#else
   for(int i = OrdersTotal(); i >= 0; i--)   //count backwards
   {
      if(OrderSelect(i, SELECT_BY_POS))   // select the order
      {
         const string commi = OrderComment();
         if(commi == "JB-That Was Easy" || commi == "That Was Easy" || commi == "Premium Button (JBlanked.com)" || commi == "JB-That Was Easy[sl]")
         {
            profit += OrderProfit() + OrderSwap() + OrderCommission();
         }
      }
   }
#endif
   return profit;
}
//+------------------------------------------------------------------+
