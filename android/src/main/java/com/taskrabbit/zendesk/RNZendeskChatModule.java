package com.taskrabbit.zendesk;

import android.app.Activity;
import android.content.Context;

import android.graphics.Color;
import android.os.Build;
import android.support.v4.content.ContextCompat;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.FrameLayout;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;

import java.lang.String;

import javax.annotation.Nullable;

import zendesk.chat.Chat;
import zendesk.chat.ChatConfiguration;
import zendesk.chat.ChatEngine;
import zendesk.chat.ChatProvider;
import zendesk.chat.ChatSessionStatus;
import zendesk.chat.ChatState;
import zendesk.chat.ObservationScope;
import zendesk.chat.Observer;
import zendesk.chat.PreChatFormFieldStatus;
import zendesk.chat.ProfileProvider;
import zendesk.chat.Providers;
import zendesk.chat.VisitorInfo;
import zendesk.core.AnonymousIdentity;
import zendesk.core.Identity;
import zendesk.messaging.MessagingActivity;
import zendesk.core.Zendesk;
import zendesk.support.Support;
import zendesk.support.guide.HelpCenterActivity;
import zendesk.support.requestlist.RequestListActivity;

public class RNZendeskChatModule extends ReactContextBaseJavaModule {

    private ReactContext mReactContext;
    private ObservationScope observationScope;
    private ChatSessionStatus chatSessionStatus;
    private Button globalChatButton;
    private ReadableMap lastChatOptions;

    private final String LOG_TAP = "Zendesk";

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

        Providers providers = Chat.INSTANCE.providers();
        if (providers == null) {
            Log.d(LOG_TAP, "Can't set visitor info, provider is null");
            return;
        }
        ProfileProvider profileProvider = providers.profileProvider();
        if (profileProvider == null) {
            Log.d(LOG_TAP, "Profile provider is null");
            return;
        }
        ChatProvider chatProvider = providers.chatProvider();
        if (chatProvider == null) {
            Log.d(LOG_TAP, "Chat provider is null");
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

    public static void init(Context context, String key) {
        Chat.INSTANCE.init(context, key);
    }

    @ReactMethod
    public void initSupport(ReadableMap options) {
        String appId = options.getString("appId");
        String clientId = options.getString("clientId");
        String url = options.getString("url");
        Context context = mReactContext;
        Zendesk.INSTANCE.init(context, url, appId, clientId);
        Support.INSTANCE.init(Zendesk.INSTANCE);
    }

    @ReactMethod
    public void setUserIdentity(ReadableMap options) {
        String name = options.getString("name");
        String email = options.getString("email");
        Identity identity = new AnonymousIdentity.Builder()
                .withNameIdentifier(name).withEmailIdentifier(email).build();
        Zendesk.INSTANCE.setIdentity(identity);
    }

    @ReactMethod
    public void showHelpCenter(ReadableMap options) {
        Activity activity = getCurrentActivity();
        if (activity != null) {
            HelpCenterActivity.builder().show(activity);
        }
    }

    @ReactMethod
    public void showTickets(ReadableMap options) {
        Activity activity = getCurrentActivity();
        if (activity != null) {
            RequestListActivity.builder().show(activity);
        }
    }

    @ReactMethod
    public void startChat(ReadableMap options) {
        lastChatOptions = options;
        if (observationScope != null) {
            observationScope.cancel();
        }
        observationScope = new ObservationScope();
        Providers providers = Chat.INSTANCE.providers();
        if (providers != null) {
            providers.chatProvider().observeChatState(observationScope, new Observer<ChatState>() {
                @Override
                public void update(ChatState chatState) {
                    chatSessionStatus = chatState.getChatSessionStatus();
                    if (chatSessionStatus == ChatSessionStatus.ENDING || chatSessionStatus == ChatSessionStatus.ENDED) {
                        removeGlobalChatButton();
                    }
                }
            });
        } else {
            Log.d(LOG_TAP, "Can't start chat observer, provider is null");
        }

        setVisitorInfo(options);

        ChatConfiguration chatConfiguration = ChatConfiguration.builder()
                .withAgentAvailabilityEnabled(true)
                .withPreChatFormEnabled(true)
                .withNameFieldStatus(PreChatFormFieldStatus.REQUIRED)
                .withEmailFieldStatus(PreChatFormFieldStatus.OPTIONAL)
                .withPhoneFieldStatus(PreChatFormFieldStatus.HIDDEN)
                .withDepartmentFieldStatus(PreChatFormFieldStatus.REQUIRED)
                .build();

        Activity activity = getCurrentActivity();
        if (activity != null) {
            if (globalChatButton == null) {
                addGlobalChatButton(options);
            }
            MessagingActivity.builder()
                    .withEngines(ChatEngine.engine())
                    .show(activity, chatConfiguration);
        }
    }

    private void addGlobalChatButton(ReadableMap options) {
        final ViewGroup root = getCurrentRootView();
        if (root == null) {
            return;
        }
        globalChatButton = new Button(mReactContext);
        globalChatButton.setText(options.getString("retainButtonTitle"));
        globalChatButton.setBackground(ContextCompat.getDrawable(mReactContext, R.drawable.global_button));
        globalChatButton.setPadding(5, 5, 5, 5);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            globalChatButton.setZ(999);
        }
        globalChatButton.setTextColor(Color.WHITE);
        globalChatButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                startChat(lastChatOptions);
            }
        });
        final FrameLayout.LayoutParams params = new FrameLayout.LayoutParams((int)mReactContext.getResources().getDimension(R.dimen.global_button_width),
                (int)mReactContext.getResources().getDimension(R.dimen.global_button_height));
        params.leftMargin = (int)mReactContext.getResources().getDimension(R.dimen.global_button_left_offset);
        params.topMargin  = root.getHeight() - (int)mReactContext.getResources().getDimension(R.dimen.global_button_bottom_offset);
        root.post(new Runnable() {
            @Override
            public void run() {
                root.addView(globalChatButton, params);
            }
        });
    }

    private void removeGlobalChatButton() {
        if (globalChatButton == null) {
            return;
        }
        ViewGroup root = getCurrentRootView();
        if (root == null) {
            return;
        }
        root.removeView(globalChatButton);

    }

    private @Nullable ViewGroup getCurrentRootView() {
        try {
            Activity activity = getCurrentActivity();
            if (activity == null) {
                return null;
            }
            return activity.findViewById(android.R.id.content);
        } catch (Exception e) {
            Log.d(LOG_TAP, "Failed to get root view", e);
        }
        return null;
    }

    @ReactMethod
    public void sendMessage(String  message) {
        Providers providers = Chat.INSTANCE.providers();
        if (providers == null) {
            Log.d(LOG_TAP, "Can't send message, providers is null");
            return;
        }
        ChatProvider chatProvider = providers.chatProvider();
        chatProvider.sendMessage(message);

    }
}
