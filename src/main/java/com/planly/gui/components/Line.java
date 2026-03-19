package com.planly.gui.components;

import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.Point;
import java.awt.RenderingHints;
import java.awt.event.KeyEvent;
import java.awt.event.MouseEvent;

import com.planly.Utils;
import com.planly.gui.DrawMode;

public class Line implements Drawable
{
    private Graphics2D gCache;
    private Point tmpStart;
    private Point start;
    private Point end;
    private DrawMode drawMode;
    private Color color;
    private boolean startCloned;
    private boolean isSelected;
    private float cachedLengthInPixels;
    private float cachedLengthInMetters;
    private float cachedDegrees;

    public Line(Graphics2D g2d)
    {
        gCache = g2d;
        tmpStart = new Point(0, 0);
        start = new Point(0, 0);
        end = new Point(0, 0);
        drawMode = DrawMode.NORMAL;
        color = Color.BLACK;
        startCloned = false;
        isSelected = false;
        cachedLengthInPixels = 0;
        cachedLengthInMetters = 0;
        cachedDegrees = 0;
    }

    public double getLengthInPixels()
    {
        return end.distance(start);
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

    public boolean isPointOnLine(int x, int y)
    {
        int dx = end.x - start.x;
        int dy = end.y - start.y;

        double numerator = Math.abs(dy * x - dx * y + end.x * start.y - end.y * start.x);
        double denominator = Math.sqrt(dx * dx + dy * dy);
        double distance = numerator / denominator;
        double tolerance = 10d;

        if (distance > tolerance) {
            return false;
        }

        // comprobar que está dentro del segmento
        double dot = (x - start.x) * dx + (y - start.y) * dy;
        if (dot < 0) {
            return false;
        }

        double lenSq = dx * dx + dy * dy;
        if (dot > lenSq) {
            return false;
        }

        return true;
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

    public void paint(Graphics2D g2d)
    {
        g2d.clearRect(0, 0, 180, 80);
        g2d.setColor(Color.BLACK);
        g2d.drawString("Píxeles: " + cachedLengthInPixels, 20, 20);
        g2d.drawString("Metros: " + cachedLengthInMetters, 20, 40);
        g2d.drawString("Grados: " + cachedDegrees, 20, 60);
        g2d.setColor(color);
        g2d.drawLine(start.x, start.y, end.x, end.y);

        if (isSelected) {
            g2d.setColor(Color.BLUE);
            g2d.drawOval(start.x - 5, start.y - 5, 10, 10);
            g2d.drawOval(end.x - 5, end.y - 5, 10, 10);
        }
    }

    public void mouseClicked(MouseEvent e)
    {
        if (isPointOnLine(e.getX(), e.getY())) {
            color = Color.RED;
            isSelected = true;
        } else {
            color = Color.BLACK;
            isSelected = false;
        }
    }

    public void mousePressed(MouseEvent e)
    {
        tmpStart.x = e.getX();
        tmpStart.y = e.getY();
    }

    public void mouseReleased(MouseEvent e)
    {
        startCloned = false;
        gCache.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        paint(gCache);
    }

    public void mouseDragged(MouseEvent e)
    {
        end.x = e.getX();
        end.y = e.getY();

        if (!startCloned) {
            start = (Point) tmpStart.clone();
            startCloned = true;
        }

        if (drawMode.equals(DrawMode.FLATTEN)) {
            flatten();
        }

        cachedLengthInPixels = Utils.round(getLengthInPixels());
        cachedLengthInMetters = Utils.round(Utils.convertToMetters(getLengthInPixels()));
        cachedDegrees = Utils.round(getDegrees());
    }

    public void keyReleased(KeyEvent e)
    {
        drawMode = DrawMode.NORMAL;
    }

    public void keyPressed(KeyEvent e)
    {
        if (e.getKeyCode() == KeyEvent.VK_SHIFT) {
            drawMode = DrawMode.FLATTEN;
        }
    }
}
