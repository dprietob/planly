package com.planly.gui;

import java.awt.event.KeyEvent;
import java.awt.event.KeyListener;
import java.awt.event.MouseEvent;
import java.awt.event.MouseListener;
import java.awt.event.MouseMotionListener;

import javax.swing.JPanel;

public class Canvas extends JPanel implements MouseListener, MouseMotionListener, KeyListener
{
    private float measureInMetters;
    private float measureInPixels;

    protected DrawMode drawMode;
    private SceneListener sceneListener;

    public Canvas()
    {
        drawMode = DrawMode.NORMAL;

        measureInMetters = 1f;
        measureInPixels = 200f;

        setDoubleBuffered(true);
        setFocusable(true);
        requestFocusInWindow();
        addMouseListener(this);
        addMouseMotionListener(this);
        addKeyListener(this);
    }

    public void mouseClicked(MouseEvent e)
    {
    }

    public void mouseEntered(MouseEvent e)
    {
    }

    public void mouseExited(MouseEvent e)
    {
    }

    public void mouseReleased(MouseEvent e)
    {
    }

    public void mousePressed(MouseEvent e)
    {
        if (sceneListener != null) {
            sceneListener.mousePressed(e);
        }
    }

    public void mouseDragged(MouseEvent e)
    {
        if (sceneListener != null) {
            sceneListener.mouseDragged(e);
        }
    }

    public void mouseMoved(MouseEvent e)
    {
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

    public void keyTyped(KeyEvent e)
    {
    }

    protected void addSceneListener(SceneListener sl)
    {
        sceneListener = sl;
    }

    protected double convertToMetters(double value)
    {
        return (value * measureInMetters) / measureInPixels;
    }

    protected float round(double value)
    {
        return (float) Math.round(value * 1000) / 1000;
    }
}
