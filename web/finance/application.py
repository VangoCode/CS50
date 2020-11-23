import os

from cs50 import SQL
from flask import Flask, flash, jsonify, redirect, render_template, request, session
from flask_session import Session
from tempfile import mkdtemp
from werkzeug.exceptions import default_exceptions, HTTPException, InternalServerError
from werkzeug.security import check_password_hash, generate_password_hash

from helpers import apology, login_required, lookup, usd

# Configure application
app = Flask(__name__)

# Ensure templates are auto-reloaded
app.config["TEMPLATES_AUTO_RELOAD"] = True

# Ensure responses aren't cached
@app.after_request
def after_request(response):
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers["Expires"] = 0
    response.headers["Pragma"] = "no-cache"
    return response

# Custom filter
app.jinja_env.filters["usd"] = usd

# Configure session to use filesystem (instead of signed cookies)
app.config["SESSION_FILE_DIR"] = mkdtemp()
app.config["SESSION_PERMANENT"] = False
app.config["SESSION_TYPE"] = "filesystem"
Session(app)

# Configure CS50 Library to use SQLite database
db = SQL("sqlite:///finance.db")

# Make sure API key is set
if not os.environ.get("API_KEY"):
    raise RuntimeError("API_KEY not set")


@app.route("/")
@login_required
def index():
    """Show portfolio of stocks"""

    rows = db.execute("SELECT * FROM stocks WHERE user_id=:sid", sid=session["user_id"])
    cash = db.execute("SELECT cash FROM users WHERE id=:sid", sid=session["user_id"])
    currentPrice = []
    for row in rows:
        stocks = lookup(row["stock_symbol"])
        currentPrice.append(stocks["price"])

    return render_template("index.html", rows=rows, cash="{:.2f}".format(cash[0]["cash"]), currentPrice=currentPrice)


@app.route("/buy", methods=["GET", "POST"])
@login_required
def buy():
    """Buy shares of stock"""

    # User reached route via POST (as by submitting a form via POST)
    if request.method == "POST":

        if not request.form.get("symbol"):
            return apology("must provide symbol", 403)

        stocks = lookup(request.form.get("symbol"))
        if (stocks == None):
            return apology("Invalid Stock Symbol", 403)

        shares = request.form.get("shares")

        if shares.isnumeric():
            if int(shares) <= 0:
                return apology("Please input a positive integer", 403)
            shares = int(shares)
        else:
            return apology("Please input an integer", 403)


        rows = db.execute("SELECT * FROM users WHERE id = :id",
                          id=session["user_id"])

        if shares * stocks["price"] > rows[0]["cash"]:
            return apology("Not enough cash", 403)


        db.execute("INSERT INTO stocks (user_id, stock_symbol, stock_count, stock_purchase_price, stock_name) VALUES (:id, :symbol, :count, :price, :name)"
        , id=session["user_id"], symbol=request.form.get("symbol"), count=shares, price=stocks["price"], name=stocks["name"])

        db.execute("INSERT INTO history (user_id, stock_name, stock_symbol, shares, stock_price, type) VALUES (:id, :stock_name, :stock_symbol, :shares, :stock_price, 'BUY')",
        id=session["user_id"], stock_name=stocks["name"], stock_symbol=request.form.get("symbol"), shares=shares, stock_price=stocks["price"])

        newCash = rows[0]["cash"]-(shares * stocks["price"])
        db.execute("UPDATE users SET cash = :cash WHERE id = :sid", cash=newCash, sid=session["user_id"])

        return redirect("/")

    # User reached route via GET (as by clicking a link or via redirect)
    else:
        return render_template("buy.html")


@app.route("/history")
@login_required
def history():
    """Show history of transactions"""

    rows = db.execute("SELECT * FROM history WHERE user_id = :id ORDER BY id DESC", id=session["user_id"])
    return render_template("history.html", rows=rows)


@app.route("/login", methods=["GET", "POST"])
def login():
    """Log user in"""

    # Forget any user_id
    session.clear()

    # User reached route via POST (as by submitting a form via POST)
    if request.method == "POST":

        # Ensure username was submitted
        if not request.form.get("username"):
            return apology("must provide username", 403)

        # Ensure password was submitted
        elif not request.form.get("password"):
            return apology("must provide password", 403)

        # Query database for username
        rows = db.execute("SELECT * FROM users WHERE username = :username",
                          username=request.form.get("username"))

        # Ensure username exists and password is correct
        if len(rows) != 1 or not check_password_hash(rows[0]["hash"], request.form.get("password")):
            return apology("invalid username and/or password", 403)

        # Remember which user has logged in
        session["user_id"] = rows[0]["id"]

        # Redirect user to home page
        return redirect("/")

    # User reached route via GET (as by clicking a link or via redirect)
    else:
        return render_template("login.html")


@app.route("/logout")
def logout():
    """Log user out"""

    # Forget any user_id
    session.clear()

    # Redirect user to login form
    return redirect("/")


@app.route("/quote", methods=["GET", "POST"])
@login_required
def quote():
    """Get stock quote."""

    # User reached route via POST (as by submitting a form via POST)
    if request.method == "POST":

        stocks = lookup(request.form.get("symbol"))
        if (stocks == None):
            return apology("Invalid Stock Symbol", 403)

        name = stocks["name"]
        price = stocks["price"]

        # Render quoted template
        return render_template("quoted.html", name=name, price=price)

    # User reached route via GET (as by clicking a link or via redirect)
    else:
        return render_template("quote.html")


@app.route("/register", methods=["GET", "POST"])
def register():
    """Register user"""

    # Forget any user_id
    session.clear()

    # User reached route via POST (as by submitting a form via POST)
    if request.method == "POST":

        # Ensure username was submitted
        if not request.form.get("username"):
            return apology("must provide username", 403)

        # Ensure password was submitted
        elif not request.form.get("password"):
            return apology("must provide password", 403)

        # Ensure comfirmed password was submitted
        elif not request.form.get("confirm_password"):
            return apology("must confirm password", 403)

        # Query database for username
        rows = db.execute("SELECT * FROM users WHERE username = :username",
                          username=request.form.get("username"))

        # Ensure username doesn't exist
        if len(rows) == 1:
            return apology("that username is already taken", 403)

        # if the passwords don't match
        if not request.form.get("password") == request.form.get("confirm_password"):
            return apology("passwords don't match", 403)

        # generate hash for password
        hashedPass = generate_password_hash(request.form.get("password"))

        db.execute("INSERT INTO users (username, hash) VALUES (:username, :hashedPass)", username=request.form.get("username"), hashedPass=hashedPass)


        # query DB to get user_id
        rows = db.execute("SELECT * FROM users WHERE username = :username",
                          username=request.form.get("username"))

        # Remember which user has logged in
        session["user_id"] = rows[0]["id"]

        # Redirect user to home page
        return redirect("/")

    # User reached route via GET (as by clicking a link or via redirect)
    else:
        return render_template("register.html")


@app.route("/sell", methods=["GET", "POST"])
@login_required
def sell():
    """Sell shares of stock"""

    # User reached route via POST (as by submitting a form via POST)
    if request.method == "POST":

        if not request.form.get("symbol"):
            return apology("must provide symbol", 403)

        stocks = lookup(request.form.get("symbol"))
        if (stocks == None):
            return apology("Invalid Stock Symbol", 403)

        shares = request.form.get("shares")

        if not shares.isnumeric():
            return apology("Please input a positive integer", 403)
        shares = int(shares)

        rows = db.execute("SELECT * FROM stocks WHERE user_id = :id AND stock_symbol = :symbol",
                          id=session["user_id"], symbol=request.form.get("symbol"))

        user = db.execute("SELECT * FROM users WHERE id = :id", id=session["user_id"])

        total = 0
        for row in rows:
            total += row["stock_count"] - row["stock_sold"]

        print(total, shares)
        if total < shares:
            return apology("You don't own that many shares.", 403)


        counter = 1
        for row in rows:
            sharesAdded = 0
            while (row["stock_sold"]+sharesAdded < row["stock_count"] and counter <= shares):
                sharesAdded += 1
                db.execute("UPDATE stocks SET stock_sold = :sold WHERE user_id = :sid AND stock_id = :stock_id", sold=row["stock_sold"]+sharesAdded, sid=session["user_id"], stock_id=row["stock_id"])
                db.execute("UPDATE users SET cash = :cash WHERE id = :id", cash=user[0]["cash"]+(sharesAdded*stocks["price"]), id=session["user_id"])
                counter+=1
            user = db.execute("SELECT * FROM users WHERE id = :id", id=session["user_id"])

        db.execute("INSERT INTO history (user_id, stock_name, stock_symbol, shares, stock_price, type) VALUES (:id, :stock_name, :stock_symbol, :shares, :stock_price, 'SELL')",
        id=session["user_id"], stock_name=stocks["name"], stock_symbol=request.form.get("symbol"), shares=shares, stock_price=stocks["price"])

        return redirect("/")

    # User reached route via GET (as by clicking a link or via redirect)
    else:
        symbols = db.execute("SELECT DISTINCT stock_symbol FROM stocks WHERE user_id = :id AND NOT stock_count = stock_sold", id=session["user_id"])
        return render_template("sell.html", symbols=symbols)


@app.route("/add", methods=["GET", "POST"])
@login_required
def add():
    """Add cash to account"""

    # User reached route via POST (as by submitting a form via POST)
    if request.method == "POST":

        if not request.form.get("cash"):
            return apology("must provide symbol", 403)

        cash = request.form.get("cash")
        if not cash.isnumeric():
            return apology("Please input a positive integer", 403)
        cash = int(cash)
        user = db.execute("SELECT * FROM users WHERE id = :id", id=session["user_id"])

        db.execute("UPDATE users SET cash = :cash WHERE id = :id",
                          cash=user[0]["cash"]+cash, id=session["user_id"])


        return redirect("/")

    # User reached route via GET (as by clicking a link or via redirect)
    else:
        return render_template("add.html")


def errorhandler(e):
    """Handle error"""
    if not isinstance(e, HTTPException):
        e = InternalServerError()
    return apology(e.name, e.code)


# Listen for errors
for code in default_exceptions:
    app.errorhandler(code)(errorhandler)
