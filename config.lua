Config = {}

Config.LoanSettings = {
    MinLoanAmount = 50,
    MaxLoanAmount = 5000,
    InterestRates = {
        [50] = 5,      -- $50-499: 5% interest
        [500] = 7.5,   -- $500-999: 7.5% interest
        [1000] = 10,   -- $1000-2499: 10% interest
        [2500] = 12.5, -- $2500+: 12.5% interest
    },
    PaymentFrequency = 7, -- Days between payments
    LatePaymentPenalty = 10, -- 10% penalty for late payment
    MaxActiveLoans = 1, -- Maximum active loans per player
}

Config.BankLocations = {
    {
        name = "Valentine Bank",
        coords = vector3(-308.32, 776.02, 118.70),
        blip = true
    },
    {
        name = "Rhodes Bank",
        coords = vector3(1294.20, -1303.26, 77.04),
        blip = true
    },
    {
        name = "Saint Denis Bank",
        coords = vector3(2644.07, -1292.30, 52.25),
        blip = true
    },
    {
        name = "Blackwater Bank",
        coords = vector3(-813.48, -1277.37, 43.64),
        blip = true
    }
}

Config.LetterSettings = {
    ReminderDaysBefore = 2, -- Send reminder 2 days before due
    Author = "Bank Manager",
    LetterItem = "letter", -- Item name for letter in inventory
}