package com.planly.gui;

import java.awt.Color;
import java.awt.Graphics;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.event.KeyEvent;
import java.awt.event.KeyListener;
import java.awt.event.MouseEvent;
import java.awt.event.MouseListener;
import java.awt.event.MouseMotionListener;
import java.awt.image.BufferedImage;
import java.util.ArrayList;
import java.util.List;

import javax.swing.JPanel;
import javax.swing.Timer;

import com.planly.Constants;
import com.planly.gui.components.Drawable;
import com.planly.gui.components.Line;

public class Scene extends JPanel implements MouseListener, MouseMotionListener, KeyListener
{
    private List<Drawable> drawables;
    private Drawable drawable;
    private BufferedImage cache;
    private Graphics2D gCache;

    public Scene()
    {
        drawables = new ArrayList<Drawable>();
        cache = new BufferedImage(Constants.WINDOW_WIDTH, Constants.WINDOW_HEIGHT, BufferedImage.TYPE_INT_ARGB);
        gCache = cache.createGraphics();

        setDoubleBuffered(true);
        setFocusable(true);
        requestFocusInWindow();
        setBackground(Color.WHITE);

        addMouseListener(this);
        addMouseMotionListener(this);
        addKeyListener(this);

        new Timer(16, e -> {
            if (drawable != null) {
                repaint();
            }
        }).start();
    }

    public void mouseClicked(MouseEvent e)
    {
        for (Drawable d : drawables) {
            d.mouseClicked(e);
        }
    }

    public void mouseEntered(MouseEvent e)
    {
    }

    public void mouseExited(MouseEvent e)
    {
    }

    public void mouseReleased(MouseEvent e)
    {
        drawable.mouseReleased(e);
    }

    public void mousePressed(MouseEvent e)
    {
        drawable = new Line(gCache);
        drawable.mousePressed(e);
        drawables.add(drawable);
    }

    public void mouseDragged(MouseEvent e)
    {
        drawable.mouseDragged(e);
    }

    public void mouseMoved(MouseEvent e)
    {
    }

    public void keyReleased(KeyEvent e)
    {
        drawable.keyReleased(e);
    }

    public void keyPressed(KeyEvent e)
    {
        drawable.keyPressed(e);
    }

    public void keyTyped(KeyEvent e)
    {
    }

    @Override
    protected void paintComponent(Graphics g)
    {
        super.paintComponent(g);

        Graphics2D g2d = (Graphics2D) g;
        g.drawImage(cache, 0, 0, null);

        g2d.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_OFF);

        // dibujas solo la línea activa
        if (drawable != null) {
            drawable.paint(g2d);
        }

        // g2d.setRenderingHint(RenderingHints.KEY_ANTIALIASING,
        // RenderingHints.VALUE_ANTIALIAS_ON);
        // g2d.setColor(Color.BLACK);
        // g2d.drawString("Usa SHIFT para modo recto", 250, 20);
        // g2d.drawString("Componentes: " + drawables.size(), 500, 20);

        // for (Drawable d : drawables) {
        // d.paint(g2d);
        // }
    }
}

/**
 * FIXME:
 * 
 * La idea de mejora de rendimiento es que sólo se dibuje y calcule la línea
 * actual y el resto se cachee dentro de BufferedImage una vez se ha terminado
 * de dibujar (mouseRelease).
 * 
 * Esto implica que no se puede redibujar las líneas ya cacheadas ya que no se
 * iteran en ningún momento, por lo que hay que arreglar eso porque si no, no se
 * pueden cambiar de estado (isSelected) o reubicar.
 * 
 * Hay que darle una vuelta al sistema de renderizado y cacheo de drawables, así
 * como a la detección de clic (isSelected) de cualquier elemento del Scene.
 * Aquí hay una amalgama de cosas que cuesta entender el código, y mira que lo
 * he escrito yo.
 */
