package com.planly;

import java.awt.EventQueue;

import javax.swing.UIManager;

import com.formdev.flatlaf.FlatDarkLaf;
import com.planly.gui.Window;

public class Planly
{
    public static void main(String[] args)
    {
        EventQueue.invokeLater(() -> {
            try {
                UIManager.setLookAndFeel(new FlatDarkLaf());
                new Window();
            } catch (Exception e) {
                e.printStackTrace();
            }
        });
    }
}
