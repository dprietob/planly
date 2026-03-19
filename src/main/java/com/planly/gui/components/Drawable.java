package com.planly.gui.components;

import java.awt.Graphics2D;
import java.awt.event.KeyEvent;
import java.awt.event.MouseEvent;

public interface Drawable
{
    public void paint(Graphics2D g2d);

    public void mouseClicked(MouseEvent e);

    public void mousePressed(MouseEvent e);

    public void mouseReleased(MouseEvent e);

    public void mouseDragged(MouseEvent e);

    public void keyReleased(KeyEvent e);

    public void keyPressed(KeyEvent e);
}
