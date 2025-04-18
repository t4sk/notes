import yfinance as yf
from lib import is_date, date_to_str, str_to_date

# https://github.com/ranaroussi/yfinance

class Price:
    def __init__(self, **kwargs):
        self.date = kwargs["date"]
        assert is_date(self.date)

        self.open = kwargs["open"]
        assert self.open >= 0

        self.close = kwargs["close"]
        assert self.close >= 0

        self.high = kwargs["high"]
        assert self.high >= 0

        self.low = kwargs["low"]
        assert self.low >= 0

        self.volume = kwargs["volume"]
        assert self.volume >= 0

    def __repr__(self):
        return f"{self.date} | {self.open:.3f} | {self.close:.3f} | {self.high:.3f} | {self.low:.3f} | {self.volume}"

class YahooFinanceAdapter:
    def __init__(self, ticker: str):
        self.yf_ticker = yf.Ticker(ticker)
        self.interval = "1d"

    def fetch(self, date_range: tuple):
        print("HERE")
        df = self.yf_ticker.history(
            start=date_range[0], end=date_range[1], interval=self.interval
        )
        # print(df.columns)
        # print(df.index)
        df.reset_index(inplace=True)
        data = df.to_dict(orient="records")

        prices = []
        for d in data:
            prices.append(Price(
                date=d["Date"].to_pydatetime(),
                open=d["Open"],
                close=d["Close"],
                high=d["High"],
                low=d["Low"],
                volume=d["Volume"]
            ))
        return prices