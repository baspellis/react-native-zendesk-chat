package com.taskrabbit.zendesk;

import android.app.Activity;
import android.util.Log;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;

import java.lang.String;

import zendesk.chat.Chat;
import zendesk.chat.ChatConfiguration;
import zendesk.chat.ChatEngine;
import zendesk.chat.ChatProvider;
import zendesk.chat.PreChatFormFieldStatus;
import zendesk.chat.ProfileProvider;
import zendesk.chat.VisitorInfo;
import zendesk.messaging.MessagingActivity;

public class RNZendeskChatModule extends ReactContextBaseJavaModule {

    private ReactContext mReactContext;

    public RNZendeskChatModule(ReactApplicationContext reactContext) {
        super(reactContext);
        mReactContext = reactContext;
    }

    @Override
    public String getName() {
        return "RNZendeskChatModule";
    }

    @ReactMethod
    public void setVisitorInfo(ReadableMap options) {

        ProfileProvider profileProvider = Chat.INSTANCE.providers().profileProvider();
        if (profileProvider == null) {
            Log.d("Zendesk", "Profile provider is null");
            return;
        }
        ChatProvider chatProvider = Chat.INSTANCE.providers().chatProvider();
        if (chatProvider == null) {
            Log.d("Zendesk", "Chat provider is null");
            return;
        }
        VisitorInfo.Builder builder = VisitorInfo.builder();
        if (options.hasKey("name")) {
            builder = builder.withName(options.getString("name"));
        }
        if (options.hasKey("email")) {
            builder = builder.withEmail(options.getString("email"));
        }
        if (options.hasKey("phone")) {
            builder = builder.withPhoneNumber(options.getString("phone"));
        }
        VisitorInfo visitorInfo = builder.build();
        profileProvider.setVisitorInfo(visitorInfo, null);
        if (options.hasKey("department"))
            chatProvider.setDepartment(options.getString("department"), null);

    }

    @ReactMethod
    public void init(String key) {

        Activity activity = getCurrentActivity();
        if (activity != null) {
            Chat.INSTANCE.init(activity, key);
        }
    }

    @ReactMethod
    public void startChat(ReadableMap options) {
        setVisitorInfo(options);

        ChatConfiguration chatConfiguration = ChatConfiguration.builder()
                .withAgentAvailabilityEnabled(false)
                .withPreChatFormEnabled(true)
                .withNameFieldStatus(PreChatFormFieldStatus.REQUIRED)
                .withEmailFieldStatus(PreChatFormFieldStatus.OPTIONAL)
                .withPhoneFieldStatus(PreChatFormFieldStatus.HIDDEN)
                .withDepartmentFieldStatus(PreChatFormFieldStatus.REQUIRED)
                .build();

        Activity activity = getCurrentActivity();
        if (activity != null) {
            MessagingActivity.builder()
                    .withEngines(ChatEngine.engine())
                    .show(activity, chatConfiguration);
        }
    }
}
