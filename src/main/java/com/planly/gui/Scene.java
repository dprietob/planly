package com.planly.gui;

import java.awt.Color;
import java.awt.Graphics;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.event.MouseEvent;

import com.planly.gui.components.Line;

public class Scene extends Canvas implements SceneListener
{
    private Line line;

    public Scene()
    {
        line = new Line();
        addSceneListener(this);
    }

    public void mousePressed(MouseEvent e)
    {
        line.setStart(e.getX(), e.getY());
    }

    public void mouseDragged(MouseEvent e)
    {
        line.setEnd(e.getX(), e.getY());

        if (drawMode.equals(DrawMode.FLATTEN)) {
            line.flatten();
        }

        repaint();
    }

    @Override
    protected void paintComponent(Graphics g)
    {
        super.paintComponent(g);

        Graphics2D g2d = (Graphics2D) g;

        g2d.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        g2d.setColor(Color.WHITE);
        g2d.fillRect(0, 0, getWidth(), getHeight());

        g2d.setColor(Color.BLACK);
        g2d.drawString("Píxeles: " + round(line.getLengthInPixels()), 20, 20);
        g2d.drawString("Metros: " + round(convertToMetters(line.getLengthInPixels())), 20, 40);
        g2d.drawString("Grados: " + round(line.getDegrees()), 20, 60);
        g2d.drawString("Usa SHIFT para modo recto", 250, 20);

        g2d.drawLine(line.getStart().x, line.getStart().y, line.getEnd().x, line.getEnd().y);
    }
}
