<?php
session_start();

// ================== CẤU HÌNH HỆ THỐNG ==================
$password = "Hoangquydzvl"; // Đổi mật khẩu của bạn ở đây
$baseDir  = "4329"; // Thư mục lưu file vật lý
$metadataFile = "metadata.json"; // File lưu database
$baseUrl  = "https://solitudepremium.click/ipa/proxy/4329/"; // URL gốc trỏ tới thư mục chứa file

// ================== HÀM TIỆN ÍCH ==================
function loadMetadata($file) {
    if (!file_exists($file)) return [];
    $data = json_decode(file_get_contents($file), true);
    return is_array($data) ? $data : [];
}

function saveMetadata($file, $data) {
    // Luôn bọc array_values để Swift parse không bị lỗi
    file_put_contents($file, json_encode(array_values($data), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
}

function listFolders($baseDir) {
    if (!is_dir($baseDir)) return [];
    $dirs = array_diff(scandir($baseDir), ['.', '..']);
    $result = [];
    foreach ($dirs as $d) {
        if (is_dir($baseDir . '/' . $d)) $result[] = $d;
    }
    return $result;
}

function rrmdir($dir) {
    if (!is_dir($dir)) return @unlink($dir);
    foreach (array_diff(scandir($dir), ['.', '..']) as $item) {
        $path = $dir . '/' . $item;
        is_dir($path) ? rrmdir($path) : @unlink($path);
    }
    return @rmdir($dir);
}

$metadata = loadMetadata($metadataFile);
$message  = "";
$messageType = "";

// ================== ĐĂNG XUẤT ==================
if (isset($_GET['logout'])) {
    session_destroy();
    header("Location: " . $_SERVER['PHP_SELF']);
    exit;
}

// ================== ĐĂNG NHẬP ==================
if (isset($_POST['login'])) {
    if ($_POST['password'] === $password) {
        $_SESSION['logged'] = true;
        header("Location: " . $_SERVER['PHP_SELF']);
        exit;
    } else {
        $message = "❌ Sai mật khẩu truy cập!";
        $messageType = "error";
    }
}

$isLogged = !empty($_SESSION['logged']);

// ================== UPLOAD FILE ==================
if ($isLogged && isset($_POST['upload'])) {
    $gameType    = $_POST['gameType'] ?? 'ffmax';
    $folder      = trim($_POST['folder'] ?? '') ?: 'Aim';
    $newFolder   = trim($_POST['new_folder'] ?? '');
    $displayName = trim($_POST['displayName'] ?? '') ?: 'New Feature';
    $note        = trim($_POST['note'] ?? '');

    if ($newFolder !== '') {
        $folder = $newFolder;
    }
    // Làm sạch tên thư mục
    $safeFolder = preg_replace('/[^A-Za-z0-9_\-]/', '_', $folder);

    if (isset($_FILES["fileToUpload"]) && $_FILES["fileToUpload"]["error"] == 0) {
        $original_name = basename($_FILES["fileToUpload"]["name"]);
        $fileType = strtolower(pathinfo($original_name, PATHINFO_EXTENSION));

        if ($fileType !== "3105") {
            $message = "❌ Lỗi: Hệ thống chỉ chấp nhận định dạng file .3105";
            $messageType = "error";
        } else {
            if (!is_dir($baseDir)) mkdir($baseDir, 0777, true);
            $targetDir = $baseDir . "/" . $safeFolder;
            if (!is_dir($targetDir)) mkdir($targetDir, 0777, true);

            // Xóa khoảng trắng trong tên file để tránh lỗi URL
            $safeName = str_replace(" ", "_", $original_name);
            $targetFilePath = $targetDir . "/" . $safeName;

            if (move_uploaded_file($_FILES["fileToUpload"]["tmp_name"], $targetFilePath)) {
                $fileUrl = $baseUrl . urlencode($safeFolder) . '/' . urlencode($safeName);
                
                // Đẩy item mới nhất lên đầu danh sách (Đồng bộ đúng struct Swift)
                array_unshift($metadata, [
                    'filename'    => $safeName,
                    'gameType'    => $gameType,
                    'folder'      => $safeFolder,
                    'displayName' => $displayName,
                    'note'        => $note,
                    'url'         => $fileUrl,
                    'time'        => date('Y-m-d H:i:s')
                ]);
                
                saveMetadata($metadataFile, $metadata);
                $message = "✅ Upload thành công: <b>$safeName</b>";
                $messageType = "success";
            } else {
                $message = "❌ Lỗi không thể lưu file lên máy chủ.";
                $messageType = "error";
            }
        }
    } else {
        $message = "❌ Vui lòng chọn file để upload.";
        $messageType = "error";
    }
}

// ================== XÓA FILE ==================
if ($isLogged && isset($_POST['delete_file'])) {
    $idx = (int)$_POST['file_index'];
    if (isset($metadata[$idx])) {
        $filePath = $baseDir . '/' . $metadata[$idx]['folder'] . '/' . $metadata[$idx]['filename'];
        if (file_exists($filePath)) @unlink($filePath);
        array_splice($metadata, $idx, 1);
        saveMetadata($metadataFile, $metadata);
        $message = "🗑️ Đã xóa file thành công.";
        $messageType = "success";
    }
}

// ================== XÓA THƯ MỤC ==================
if ($isLogged && isset($_POST['delete_folder'])) {
    $folderName = preg_replace('/[^A-Za-z0-9_\-]/', '_', $_POST['folder_name'] ?? '');
    $folderPath = $baseDir . '/' . $folderName;
    if ($folderName && is_dir($folderPath)) {
        rrmdir($folderPath);
        $metadata = array_values(array_filter($metadata, function($m) use ($folderName) {
            return $m['folder'] !== $folderName;
        }));
        saveMetadata($metadataFile, $metadata);
        $message = "🗑️ Đã xóa toàn bộ thư mục: <b>$folderName</b>";
        $messageType = "success";
    }
}

$existingFolders = listFolders($baseDir);
?>
<!DOCTYPE html>
<html lang="vi">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Zenith Solitude - Quản Lý Data</title>
<style>
    :root { --bg: #09090b; --card: #18181b; --border: #27272a; --text: #fafafa; --mut: #a1a1aa; --prim: #ffffff; }
    * { box-sizing: border-box; }
    body { font-family: -apple-system, system-ui, sans-serif; background: var(--bg); color: var(--text); padding: 20px; margin: 0; line-height: 1.5; }
    .container { max-width: 800px; margin: auto; background: var(--card); padding: 24px; border-radius: 16px; border: 1px solid var(--border); box-shadow: 0 20px 40px rgba(0,0,0,0.8); }
    h2, h3 { margin-top: 0; font-weight: 800; letter-spacing: 0.5px; }
    h3 { margin-top: 30px; border-left: 3px solid var(--prim); padding-left: 10px; }
    label { display: block; margin: 14px 0 6px; font-weight: 600; font-size: 14px; color: var(--mut); }
    select, input[type=text], input[type=password], input[type=file] { width: 100%; padding: 12px; background: var(--bg); border: 1px solid var(--border); color: var(--text); border-radius: 8px; font-size: 14px; outline: none; transition: 0.2s; }
    select:focus, input:focus { border-color: #555; }
    button, input[type=submit] { background: var(--prim); color: #000; border: none; padding: 12px 20px; border-radius: 8px; font-size: 15px; font-weight: 700; cursor: pointer; transition: 0.2s; width: 100%; margin-top: 15px; }
    button:hover, input[type=submit]:hover { opacity: 0.8; }
    .btn-danger { background: #ef4444 !important; color: #fff !important; width: auto; padding: 6px 12px; font-size: 12px; margin-top: 0; }
    .btn-danger:hover { background: #dc2626 !important; }
    .msg { padding: 12px; border-radius: 8px; margin-bottom: 20px; font-size: 14px; }
    .msg.success { background: rgba(34,197,94,0.1); border: 1px solid #22c55e; color: #4ade80; }
    .msg.error { background: rgba(239,68,68,0.1); border: 1px solid #ef4444; color: #f87171; }
    .flex-header { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--border); padding-bottom: 15px; margin-bottom: 20px; }
    .flex-header a { color: #f87171; text-decoration: none; font-size: 14px; font-weight: bold; }
    .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; }
    @media (max-width: 600px) { .grid { grid-template-columns: 1fr; gap: 0; } }
    .file-card { background: var(--bg); border: 1px solid var(--border); border-radius: 12px; padding: 16px; margin-bottom: 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; }
    .file-info .title { font-weight: bold; font-size: 16px; margin-bottom: 4px; }
    .file-info .meta { font-size: 12px; color: var(--mut); }
    .badge { background: #27272a; padding: 3px 8px; border-radius: 6px; font-size: 11px; margin-right: 6px; color: #e4e4e7; }
    .badge-game { background: #fff; color: #000; font-weight: bold; }
    .folder-chips { display: flex; gap: 10px; flex-wrap: wrap; margin-top: 10px; }
    .chip { background: var(--bg); border: 1px solid var(--border); padding: 8px 12px; border-radius: 8px; display: flex; align-items: center; gap: 10px; font-size: 14px; }
</style>
</head>
<body>

<div class="container">
    <div class="flex-header">
        <h2 style="margin:0;">⚙️ Zenith Solitude</h2>
        <?php if ($isLogged): ?>
            <a href="?logout=1">Đăng xuất</a>
        <?php endif; ?>
    </div>

    <?php if ($message): ?>
        <div class="msg <?= $messageType ?>"><?= $message ?></div>
    <?php endif; ?>

    <?php if (!$isLogged): ?>
        <form method="post">
            <label>Mật khẩu hệ thống</label>
            <input type="password" name="password" required autofocus placeholder="Nhập mật khẩu...">
            <input type="submit" name="login" value="Đăng Nhập">
        </form>
    <?php else: ?>
        
        <h3>📤 Upload Cấu Hình Mới</h3>
        <form method="post" enctype="multipart/form-data">
            <div class="grid">
                <div>
                    <label>Game</label>
                    <select name="gameType" required>
                        <option value="ffmax">Free Fire Max</option>
                        <option value="ffnormal">Free Fire Thường</option>
                    </select>
                </div>
                <div>
                    <label>Thư mục hiển thị</label>
                    <select name="folder">
                        <option value="Aim">Aim</option>
                        <option value="ModSkin">ModSkin</option>
                        <option value="Chams">Chams</option>
                        <?php foreach ($existingFolders as $f): ?>
                            <?php if(!in_array($f, ['Aim','ModSkin','Chams'])) echo "<option value='$f'>$f</option>"; ?>
                        <?php endforeach; ?>
                    </select>
                </div>
            </div>

            <label>Hoặc tạo thư mục mới (Nhập sẽ ưu tiên hơn chọn)</label>
            <input type="text" name="new_folder" placeholder="Ví dụ: Guns, VIP...">

            <label>Tên hiển thị trên App (displayName)</label>
            <input type="text" name="displayName" required placeholder="Ví dụ: AimLock Head 100%">

            <label>Ghi chú (Tùy chọn)</label>
            <input type="text" name="note" placeholder="Ví dụ: Để DNS, vô sảnh bật log...">

            <label>File Config (.3105)</label>
            <input type="file" name="fileToUpload" accept=".3105" required>

            <input type="submit" name="upload" value="Tải Lên Hệ Thống">
        </form>

        <h3>📁 Quản Lý Thư Mục (<?= count($existingFolders) ?>)</h3>
        <div class="folder-chips">
            <?php if (empty($existingFolders)) echo "<span class='meta'>Chưa có thư mục.</span>"; ?>
            <?php foreach ($existingFolders as $f): ?>
                <div class="chip">
                    <span>📂 <?= htmlspecialchars($f) ?></span>
                    <form method="post" style="margin:0;" onsubmit="return confirm('Xóa thư mục sẽ xóa toàn bộ file bên trong. Bạn chắc chứ?');">
                        <input type="hidden" name="folder_name" value="<?= htmlspecialchars($f) ?>">
                        <button type="submit" name="delete_folder" class="btn-danger">Xóa</button>
                    </form>
                </div>
            <?php endforeach; ?>
        </div>

        <h3>📄 Quản Lý File (<?= count($metadata) ?>)</h3>
        <div>
            <?php if (empty($metadata)) echo "<span class='meta'>Chưa có file nào.</span>"; ?>
            <?php foreach ($metadata as $idx => $item): ?>
                <div class="file-card">
                    <div class="file-info">
                        <div class="title"><?= htmlspecialchars($item['displayName']) ?></div>
                        <div class="meta">
                            <span class="badge badge-game"><?= htmlspecialchars($item['gameType']) ?></span>
                            <span class="badge">📁 <?= htmlspecialchars($item['folder']) ?></span>
                            <span class="badge">📄 <?= htmlspecialchars($item['filename']) ?></span>
                            <?php if(!empty($item['note'])): ?><br><span style="display:inline-block; margin-top:6px;">📝 <?= htmlspecialchars($item['note']) ?></span><?php endif; ?>
                        </div>
                    </div>
                    <form method="post" style="margin:0;" onsubmit="return confirm('Bạn muốn xóa file này?');">
                        <input type="hidden" name="file_index" value="<?= $idx ?>">
                        <button type="submit" name="delete_file" class="btn-danger">Xóa</button>
                    </form>
                </div>
            <?php endforeach; ?>
        </div>
    <?php endif; ?>
</div>

</body>
</html>
