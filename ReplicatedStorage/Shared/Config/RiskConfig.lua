local RiskConfig = {
    MaxRisk = 100,
    InitialRisk = 10,
    Threshold = { Safe = 30, Uneasy = 30, Dangerous = 60, Critical = 80 },
    Accumulation = {
        NormalKill = 8,
        EliteKill = 12,
        BossKill = 20,
    },
    Decay = {
        BaseDecayPerTick = 1,
        RealDecayInterval = 120,
        MinRisk = 10,
        GongDeBoostPer20 = 0.5,
    },
    GongDeMitigation = {
        Small = { GongDeCost = 10, RiskReduction = 5, Cooldown = 0 },
        Medium = { GongDeCost = 30, RiskReduction = 20, Cooldown = 1800 },
        Large = { GongDeCost = 80, RiskReduction = 50, Cooldown = 7200 },
    },
    SpawnModifiers = {
        [0] = { EliteChance = 0, BossChance = 0, RampageChance = 0 },
        [30] = { EliteChance = 0.05, BossChance = 0, RampageChance = 0 },
        [60] = { EliteChance = 0.15, BossChance = 0.05, RampageChance = 0 },
        [80] = { EliteChance = 0.30, BossChance = 0.15, RampageChance = 0.05 },
    },
    RampageMultipliers = {
        HPMult = 2.0, DamageMult = 1.5, SpeedMult = 1.3,
        AggroRangeMult = 1.5, FleeRangeMult = 2.0,
    },
    RampageInvasion = {
        ExpPenaltyPercent = 0.05,
        InvasionDuration = 300,
        PacifyGongDeCost = 50,
    },
    RiskLevelNames = {
        [0] = "风平浪静", [30] = "妖气隐现", [60] = "危机四伏", [80] = "大凶之兆",
    },
}
return RiskConfig