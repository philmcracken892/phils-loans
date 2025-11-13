Config = {}

Config.LoanSettings = {
    MinLoanAmount = 50,
    MaxLoanAmount = 5000,
    InterestRates = {
        [50] = 5,
        [500] = 7.5,
        [1000] = 10,
        [2500] = 12.5,
    },
    PaymentFrequency = 7,
    LatePaymentPenalty = 10,
    MaxActiveLoans = 1,
    
    -- New: Overdue Consequences
    EnableCollections = true,
    CollectionsDays = 30,           -- Days until collections
    AutoDeductAfterDays = 14,       -- Auto-take cash after X days
    SeizeCashInCollections = true,  -- Take all cash when in collections
    JailForCollections = false,     -- Send to jail (requires jail system)
    JailTime = 30,                  -- Minutes in jail
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
