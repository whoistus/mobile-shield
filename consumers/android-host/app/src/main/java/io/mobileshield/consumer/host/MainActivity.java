package io.mobileshield.consumer.host;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;
import android.widget.TextView;

import io.mobileshield.MobileShield;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        String msg = "sdkVersion=" + MobileShield.getSdkVersion();
        Log.i("MobileShieldHost", msg);
        TextView tv = new TextView(this);
        tv.setText(msg);
        setContentView(tv);
    }
}
