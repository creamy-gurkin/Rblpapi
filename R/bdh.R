
##  Copyright (C) 2015 - 2022  Whit Armstrong and Dirk Eddelbuettel and John Laing
##
##  This file is part of Rblpapi
##
##  Rblpapi is free software: you can redistribute it and/or modify
##  it under the terms of the GNU General Public License as published by
##  the Free Software Foundation, either version 2 of the License, or
##  (at your option) any later version.
##
##  Rblpapi is distributed in the hope that it will be useful,
##  but WITHOUT ANY WARRANTY; without even the implied warranty of
##  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##  GNU General Public License for more details.
##
##  You should have received a copy of the GNU General Public License
##  along with Rblpapi.  If not, see <http://www.gnu.org/licenses/>.


##' This function uses the Bloomberg API to retrieve 'bdh' (Bloomberg
##' Data History) queries
##'
##' @title Run 'Bloomberg Data History' Queries
##' @param securities A character vector with security symbols in
##' Bloomberg notation.
##' @param fields A character vector with Bloomberg query fields.
##' @param start.date A Date variable with the query start date.
##' @param end.date An optional Date variable with the query end date;
##' if omitted the most recent available date is used.
##' @param include.non.trading.days An optional logical variable
##' indicating whether non-trading days should be included.
##' @param options An optional named character vector with option
##' values. Each field must have both a name (designating the option
##' being set) as well as a value.
##' @param overrides An optional named character vector with override
##' values. Each field must have both a name (designating the override
##' being set) as well as a value.
##' @param verbose A boolean indicating whether verbose operation is
##' desired, defaults to \sQuote{FALSE}
##' @param returnAs A character variable describing the type of return
##' object; currently supported are \sQuote{data.frame} (also the default),
##' \sQuote{data.table}, \sQuote{fts}, \sQuote{xts} and \sQuote{zoo}
##' @param identity An optional identity object as created by a
##' \code{blpAuthenticate} call, and retrieved via the internal function
##' \code{defaultAuthentication}.
##' @param con A connection object as created by a \code{blpConnect}
##' call, and retrieved via the internal function
##' \code{defaultConnection}.
##' @param int.as.double A boolean indicating whether integer fields should
##' be retrieved as doubles instead. This option is a workaround for very
##' large values which would overflow int32. Defaults to \sQuote{FALSE}.
##' @param simplify A boolean indicating whether result objects that are one
##' element lists should be altered to returned just the single inner object.
##' Defaults to the value of the \sQuote{blpSimplify} option, with a fallback
##' of \sQuote{TRUE} if unset ensuring prior behavior is maintained.
##' @return A list with as a many entries as there are entries in
##' \code{securities}; each list contains a object of type \code{returnAs} with one row
##' per observations and as many columns as entries in
##' \code{fields}. If the list is of length one, it is collapsed into
##' a single object of type \code{returnAs}. Note that the order of securities returned
##' is determined by the backend and may be different from the order
##' of securities in the \code{securities} field.
##' @seealso For historical futures series, see \sQuote{DOCS #2072138 <GO>}
##' on the Bloomberg terminal about selecting different rolling conventions.
##' @author Whit Armstrong and Dirk Eddelbuettel
##' @examples
##' \dontrun{
##'   bdh("SPY US Equity", c("PX_LAST", "VOLUME"), start.date=Sys.Date()-31)
##'
##'   ## example for an options field: request monthly data; see section A.2.4 of
##'   ##  http://www.bloomberglabs.com/content/uploads/sites/2/2014/07/blpapi-developers-guide-2.54.pdf
##'   ## for more
##'   opt <- c("periodicitySelection"="MONTHLY")
##'   bdh("SPY US Equity", c("PX_LAST", "VOLUME"),
##'       start.date=Sys.Date()-31*6, options=opt)
##'
##'   ## example for non-date start
##'   bdh("SPY US Equity", c("PX_LAST", "VOLUME"),
##'       start.date="-6CM", options=opt)
##'
##'   ## example for options and overrides
##'   opt <- c("periodicitySelection"="QUARTERLY")
##'   ovrd <- c("BEST_FPERIOD_OVERRIDE"="1GQ")
##'   bdh("IBM US Equity", "BEST_SALES", start.date=Sys.Date()-365.25*4,
##'       options=opt, overrides=ovrd)
##'
##'   ## example for returnRelativeDate option
##'   opt <- c(periodicitySelection="YEARLY", periodicityAdjustment="FISCAL", returnRelativeDate=TRUE)
##'   bdh("GLB ID Equity", "CUR_MKT_CAP", as.Date("1997-12-31"), as.Date("2017-12-31"), options=opt)
##' }
bdh <- function(securities, fields, start.date, end.date=NULL,
                include.non.trading.days=FALSE, options=NULL, overrides=NULL,
                verbose=FALSE, returnAs=getOption("bdhType", "data.frame"), 
                identity=defaultAuthentication(), con=defaultConnection(),
                int.as.double=getOption("blpIntAsDouble", FALSE),
                simplify=getOption("blpSimplify", TRUE)) {
    match.arg(returnAs, c("data.frame", "fts", "xts", "zoo", "data.table"))
    if (class(start.date) == "Date") {
        start.date <- format(start.date, format="%Y%m%d")
    }
    if (!is.null(end.date)) {
        end.date <- format(end.date, format="%Y%m%d")
    }

    if (include.non.trading.days) {
        options <- c(options,
                     structure(c("ALL_CALENDAR_DAYS", "NIL_VALUE"),
                               names=c("nonTradingDayFillOption", "nonTradingDayFillMethod")))
    }

    res <- bdh_Impl(con, securities, fields, start.date, end.date, options, overrides,
                    verbose, identity, int.as.double)
    
    res <- switch(returnAs,
                  data.frame = res,            # default is data.frame
                  fts        = lapply(res, function(x) fts::fts(x[,1], x[,-1, drop = FALSE])),
                  xts        = lapply(res, function(x) xts::xts(x[,-1, drop = FALSE], order.by = x[,1])),
                  zoo        = lapply(res, function(x) zoo::zoo(x[,-1, drop = FALSE], order.by = x[,1])),
                  data.table = lapply(res, function(x) data.table::data.table(date = data.table::as.IDate(x[, 1]), x[, -1, drop = FALSE])),
                  res)
  
    if (typeof(res)=="list" && length(res)==1 && simplify) {
        res <- res[[1]]
    }
    res
}
