package com.planly.gui.components;

import java.awt.Point;

public class Line
{
    private Point start;
    private Point end;

    public Line()
    {
        start = new Point(0, 0);
        end = new Point(0, 0);
    }

    public void setStart(int x, int y)
    {
        start.x = x;
        start.y = y;
    }

    public void setEnd(int x, int y)
    {
        end.x = x;
        end.y = y;
    }

    public Point getStart()
    {
        return start;
    }

    public Point getEnd()
    {
        return end;
    }

    public void flatten()
    {
        double degrees = getDegrees();

        if (degrees >= 23 && degrees < 68) {
            double dx = getLengthInPixels() * Math.cos(Math.toRadians(45));
            double dy = getLengthInPixels() * Math.sin(Math.toRadians(45));

            end.x = (int) Math.round(start.x + dx);
            end.y = (int) Math.round(start.y + dy);
        }

        if (degrees >= 68 && degrees < 113) {
            end.x = start.x;
        }

        if (degrees >= 113 && degrees < 158) {
            double dx = getLengthInPixels() * Math.cos(Math.toRadians(135));
            double dy = getLengthInPixels() * Math.sin(Math.toRadians(135));

            end.x = (int) Math.round(start.x + dx);
            end.y = (int) Math.round(start.y + dy);
        }

        if (degrees >= 158 && degrees < 203) {
            end.y = start.y;
        }

        if (degrees >= 203 && degrees < 248) {
            double dx = getLengthInPixels() * Math.cos(Math.toRadians(225));
            double dy = getLengthInPixels() * Math.sin(Math.toRadians(225));

            end.x = (int) Math.round(start.x + dx);
            end.y = (int) Math.round(start.y + dy);
        }

        if (degrees >= 248 && degrees < 293) {
            end.x = start.x;
        }

        if (degrees >= 293 && degrees < 335) {
            double dx = getLengthInPixels() * Math.cos(Math.toRadians(315));
            double dy = getLengthInPixels() * Math.sin(Math.toRadians(315));

            end.x = (int) Math.round(start.x + dx);
            end.y = (int) Math.round(start.y + dy);
        }

        if (degrees >= 335 || degrees < 23) {
            end.y = start.y;
        }
    }

    public double getLengthInPixels()
    {
        return end.distance(start);
    }

    public double getDegrees()
    {
        double dx = end.x - start.x;
        double dy = end.y - start.y;
        double degrees = Math.toDegrees(Math.atan2(dy, dx));

        if (degrees < 0) {
            degrees += 360;
        }

        return degrees;
    }
}
