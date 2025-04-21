import csv
import yfinance as yf
import matplotlib.pyplot as plt
from typing import List, Tuple
from lib import is_date, date_to_str, str_to_date, parse_float

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

    def fetch(self, date_range: Tuple[str, str]) -> List[Price]:
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


def read_csv(file_path: str, skip):
    prices = []
    with open(file_path, newline="\n", encoding="utf8", errors="errors") as csvfile:
        reader = csv.reader(csvfile, delimiter=",", quotechar="|")

        for i in range(skip):
            next(reader, None)

        for i, row in enumerate(reader):
            # print(i, row)
            p = Price(
                date=str_to_date(row[0]),
                open=parse_float(row[1]),
                close=parse_float(row[2]),
                high=parse_float(row[3]),
                low=parse_float(row[4]),
                volume=int(row[5])
            )
            prices.append(p)
    return prices


def save_csv(file_path: str, prices: List[Price]):
    rows = [
        [
            "date",
            "open",
            "close",
            "high",
            "low",
            "volume",
        ]
    ]
    for p in prices:
        rows.append(
            [
                date_to_str(p.date),
                p.open,
                p.close,
                p.high,
                p.low,
                p.volume,
            ]
        )

    with open(file_path, "w", newline="\n", encoding="utf8", errors="errors") as file:
        writer = csv.writer(
            file, delimiter=",", quotechar="|", quoting=csv.QUOTE_MINIMAL
        )

        for row in rows:
            writer.writerow(row)

        print(f"Saved to {file_path}")

def plot(prices: List[Price]):
    plt.style.use("seaborn")
    
    x = [p.date for p in prices]
    y = [p.close for p in prices]
    
    plt.plot(x, y)
    plt.show()