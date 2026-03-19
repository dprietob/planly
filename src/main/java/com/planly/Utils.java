package com.planly;

public enum Utils {
    INSTANCE;

    public static float round(double value)
    {
        return (float) Math.round(value * 1000) / 1000;
    }

    public static double convertToMetters(double value)
    {
        return (value * Constants.MEASURE_IN_METTERS) / Constants.MEASURE_IN_PIXELS;
    }
}
