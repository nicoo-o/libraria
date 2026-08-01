package com.example.libraria

import android.content.Context
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

// [Correctif] audio_service exige que l'Activity fournisse SON FlutterEngine
// partage (via AudioServicePlugin.getFlutterEngine) plutot qu'un FlutterActivity
// standard qui en cree un nouveau. Sans ca, AudioServicePlugin.onAttachedToActivity
// leve une PlatformException ("The Activity class declared in your
// AndroidManifest.xml is wrong or has not provided the correct FlutterEngine")
// des le demarrage -- et comme audio_service est enregistre en premier dans
// GeneratedPluginRegistrant, cet echec empeche tous les plugins ActivityAware
// suivants (dont permission_handler) de recevoir leur reference a l'Activity,
// d'ou le "Unable to detect current Android Activity" systematique observe.
class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return AudioServicePlugin.getFlutterEngine(context)
    }
}