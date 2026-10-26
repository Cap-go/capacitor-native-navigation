package app.capgo.nativenavigation;

import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class SvgPathDataSupport {

    private static final Pattern NUMBER_PATTERN = Pattern.compile("[-+]?(?:\\d*\\.\\d+|\\d+\\.?)(?:[eE][-+]?\\d+)?");

    private SvgPathDataSupport() {}

    /**
     * androidx.core PathParser greedily parses numbers, so compact arc flags such as {@code 0010}
     * (meaning {@code 0 0 10}) are misread. This inserts separators before calling the parser.
     */
    public static String normalizeArcFlagsInPathData(String pathData) {
        if (pathData == null || pathData.isEmpty()) {
            return pathData;
        }
        List<String> tokens = tokenize(pathData);
        if (!containsArcCommand(tokens)) {
            return pathData;
        }

        StringBuilder normalized = new StringBuilder(pathData.length() + 16);
        char command = 0;
        int arcParameterIndex = 0;

        for (String token : tokens) {
            if (isCommandToken(token)) {
                appendToken(normalized, token);
                command = token.charAt(0);
                arcParameterIndex = 0;
                continue;
            }

            String remainder = token;
            while (!remainder.isEmpty()) {
                if (command == 'a' || command == 'A') {
                    if ((arcParameterIndex == 3 || arcParameterIndex == 4)
                        && (remainder.charAt(0) == '0' || remainder.charAt(0) == '1')) {
                        appendToken(normalized, remainder.substring(0, 1));
                        remainder = remainder.substring(1);
                        arcParameterIndex = (arcParameterIndex + 1) % 7;
                        continue;
                    }
                }

                appendToken(normalized, remainder);
                if (command == 'a' || command == 'A') {
                    arcParameterIndex = (arcParameterIndex + 1) % 7;
                }
                remainder = "";
            }
        }

        return normalized.toString();
    }

    private static boolean containsArcCommand(List<String> tokens) {
        for (String token : tokens) {
            if (token.length() == 1 && (token.charAt(0) == 'a' || token.charAt(0) == 'A')) {
                return true;
            }
        }
        return false;
    }

    private static boolean isCommandToken(String token) {
        return token.length() == 1 && Character.isLetter(token.charAt(0));
    }

    private static void appendToken(StringBuilder builder, String token) {
        if (builder.length() > 0) {
            builder.append(' ');
        }
        builder.append(token);
    }

    static List<String> tokenize(String pathData) {
        List<String> tokens = new ArrayList<>();
        int index = 0;
        while (index < pathData.length()) {
            char character = pathData.charAt(index);
            if (Character.isWhitespace(character) || character == ',') {
                index++;
                continue;
            }
            if (Character.isLetter(character)) {
                tokens.add(String.valueOf(character));
                index++;
                continue;
            }

            Matcher matcher = NUMBER_PATTERN.matcher(pathData.substring(index));
            if (matcher.lookingAt()) {
                tokens.add(matcher.group());
                index += matcher.group().length();
            } else {
                index++;
            }
        }
        return tokens;
    }
}
