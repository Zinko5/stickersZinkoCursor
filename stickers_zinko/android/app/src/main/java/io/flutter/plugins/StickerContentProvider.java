package io.flutter.plugins;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.UriMatcher;
import android.database.Cursor;
import android.net.Uri;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.content.res.AssetFileDescriptor;
import android.content.res.AssetManager;
import android.database.MatrixCursor;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.util.List;
import android.os.ParcelFileDescriptor;

public class StickerContentProvider extends ContentProvider {

    private static final String AUTHORITY = "com.zinko.stickers.provider";
    private static final int METADATA = 1;
    private static final int METADATA_ID = 2;
    private static final int STICKERS = 3;
    private static final int STICKERS_ASSET = 4;

    private static final UriMatcher uriMatcher = new UriMatcher(UriMatcher.NO_MATCH);

    static {
        uriMatcher.addURI(AUTHORITY, "metadata", METADATA);
        uriMatcher.addURI(AUTHORITY, "metadata/*", METADATA_ID);
        uriMatcher.addURI(AUTHORITY, "stickers/*", STICKERS);
        uriMatcher.addURI(AUTHORITY, "stickers_asset/*/*", STICKERS_ASSET);
    }

    @Override
    public boolean onCreate() {
        return true;
    }

    @Nullable
    @Override
    public Cursor query(@NonNull Uri uri, @Nullable String[] projection, @Nullable String selection,
                        @Nullable String[] selectionArgs, @Nullable String sortOrder) {
        try {
            InputStream is = new FileInputStream(new File(getContext().getFilesDir(), "stickers.json"));
            byte[] buffer = new byte[is.available()];
            is.read(buffer);
            is.close();
            String json = new String(buffer, "UTF-8");
            JSONObject jsonObject = new JSONObject(json);

            switch (uriMatcher.match(uri)) {
                case METADATA:
                    JSONArray packs = jsonObject.getJSONArray("sticker_packs");
                    MatrixCursor metadataCursor = new MatrixCursor(new String[]{"identifier", "name", "publisher"});
                    for (int i = 0; i < packs.length(); i++) {
                        JSONObject pack = packs.getJSONObject(i);
                        metadataCursor.addRow(new Object[]{pack.getString("identifier"), pack.getString("name"), pack.getString("publisher")});
                    }
                    return metadataCursor;
                case METADATA_ID:
                    String id = uri.getLastPathSegment();
                    JSONArray allPacks = jsonObject.getJSONArray("sticker_packs");
                    for (int i = 0; i < allPacks.length(); i++) {
                        JSONObject pack = allPacks.getJSONObject(i);
                        if (pack.getString("identifier").equals(id)) {
                            MatrixCursor packCursor = new MatrixCursor(new String[]{"identifier", "name", "publisher"});
                            packCursor.addRow(new Object[]{pack.getString("identifier"), pack.getString("name"), pack.getString("publisher")});
                            return packCursor;
                        }
                    }
                    break;
                case STICKERS:
                    String packId = uri.getLastPathSegment();
                    JSONArray packsArray = jsonObject.getJSONArray("sticker_packs");
                    for (int i = 0; i < packsArray.length(); i++) {
                        JSONObject pack = packsArray.getJSONObject(i);
                        if (pack.getString("identifier").equals(packId)) {
                            JSONArray stickers = pack.getJSONArray("stickers");
                            MatrixCursor stickersCursor = new MatrixCursor(new String[]{"image_file", "emojis"});
                            for (int j = 0; j < stickers.length(); j++) {
                                JSONObject sticker = stickers.getJSONObject(j);
                                stickersCursor.addRow(new Object[]{sticker.getString("image_file"), sticker.getJSONArray("emojis").toString()});
                            }
                            return stickersCursor;
                        }
                    }
                    break;
                case STICKERS_ASSET:
                    List<String> pathSegments = uri.getPathSegments();
                    String assetPackId = pathSegments.get(1);
                    String assetFileName = pathSegments.get(2);
                    File file = new File(getContext().getFilesDir(), assetPackId + "/" + assetFileName);
                    if (file.exists()) {
                        return new AssetFileDescriptor(ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY), 0, AssetFileDescriptor.UNKNOWN_LENGTH);
                    }
                    break;
                default:
                    throw new IllegalArgumentException("URI desconocida: " + uri);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return null;
    }

    @Nullable
    @Override
    public String getType(@NonNull Uri uri) {
        return null;
    }

    @Nullable
    @Override
    public Uri insert(@NonNull Uri uri, @Nullable ContentValues values) {
        return null;
    }

    @Override
    public int delete(@NonNull Uri uri, @Nullable String selection, @Nullable String[] selectionArgs) {
        return 0;
    }

    @Override
    public int update(@NonNull Uri uri, @Nullable ContentValues values, @Nullable String selection,
                      @Nullable String[] selectionArgs) {
        return 0;
    }
}