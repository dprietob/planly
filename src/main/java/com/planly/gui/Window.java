package com.planly.gui;

import java.awt.BorderLayout;
import java.awt.Dimension;

import javax.swing.JFrame;
import javax.swing.JPanel;
import javax.swing.WindowConstants;

import com.planly.Constants;

public class Window extends JFrame
{
    private Scene scene;

    public Window()
    {
        scene = new Scene();

        JPanel mainPanel = new JPanel();
        mainPanel.setLayout(new BorderLayout());
        // mainPanel.setBorder(new EmptyBorder(0, 10, 10, 10));
        mainPanel.add(scene, BorderLayout.CENTER);

        setContentPane(mainPanel);
        build();
    }

    private void build()
    {
        setTitle(Constants.NAME + " " + Constants.VERSION);
        setSize(new Dimension(Constants.WINDOW_WIDTH, Constants.WINDOW_HEIGHT));
        setVisible(true);
        setLocationRelativeTo(null);
        setDefaultCloseOperation(WindowConstants.DISPOSE_ON_CLOSE);
    }
}
