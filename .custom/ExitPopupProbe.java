import java.awt.event.MouseEvent;
import java.awt.event.MouseListener;
import java.lang.reflect.Field;
import java.util.Timer;
import java.util.TimerTask;
import javax.swing.JLabel;
import javax.swing.SwingUtilities;
import shutterencoder.ui.main.Shutter;
import shutterencoder.ui.others.Donate;
import shutterencoder.utils.Utils;

// Integration probe: restoring the donation branch must prevent a clean exit.
// Uses the real application, settings writer, cleanup, and close-button handler.
public class ExitPopupProbe {
    public static void main(String[] args) throws Exception {
        Shutter.main(new String[0]);
        if (!Shutter.frame.isShowing()) {
            throw new AssertionError("Main application window did not open");
        }
        System.out.println("STARTUP_OK version=" + Shutter.actualVersion);
        Shutter.showDonateWindow = true;
        if (args.length > 0 && args[0].equals("email")) {
            Donate.textMailDonate.setText("local-regression@example.invalid");
        }
        Timer watchdog = new Timer(true);
        watchdog.schedule(new TimerTask() {
            public void run() {
                boolean popup = Donate.frame != null && Donate.frame.isShowing();
                System.err.println("FAIL: normal close did not exit; donationPopup=" + popup);
                System.exit(2);
            }
        }, 8000);
        SwingUtilities.invokeAndWait(() -> {
            System.out.println("CLOSE_TRIGGERED donationFlag=" + Shutter.showDonateWindow);
            System.out.flush();
            if (args.length > 0 && args[0].equals("alternate")) {
                Utils.exitApp(false);
                return;
            }
            try {
                Field field = Shutter.class.getDeclaredField("quit");
                field.setAccessible(true);
                JLabel button = (JLabel) field.get(null);
                MouseEvent press = new MouseEvent(button, MouseEvent.MOUSE_PRESSED,
                    System.currentTimeMillis(), 0, 5, 5, 1, false, MouseEvent.BUTTON1);
                MouseEvent release = new MouseEvent(button, MouseEvent.MOUSE_RELEASED,
                    System.currentTimeMillis(), 0, 5, 5, 1, false, MouseEvent.BUTTON1);
                for (MouseListener listener : button.getMouseListeners()) listener.mousePressed(press);
                for (MouseListener listener : button.getMouseListeners()) listener.mouseReleased(release);
            } catch (Exception error) {
                throw new RuntimeException(error);
            }
        });
    }
}
