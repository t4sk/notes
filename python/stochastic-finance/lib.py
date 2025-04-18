from datetime import datetime, timedelta

DATE_FORMAT = "%Y-%m-%d %H:%M:%S"


def str_to_date(date_str):
    return datetime.strptime(date_str, DATE_FORMAT)


def date_to_str(date, fmt=DATE_FORMAT):
    return date.strftime(fmt)


def is_date(date):
    return type(date) is datetime