package io.mobileshield.example.host;

import android.app.Activity;
import android.os.Bundle;
import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        startActivity(FlutterActivity.createDefaultIntent(this));
        finish();
    }
}
