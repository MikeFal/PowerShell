#requires -Version 2.0 
#From Script Gallery (https://gallery.technet.microsoft.com/scriptcenter/cb72e4e6-4a68-4a2e-89b7-cc43a860349e#content)
 
$STD_OUTPUT_HANDLE = -11 
 
$source = @" 
    public delegate bool SetConsoleFont( 
        IntPtr hWnd, 
        uint DWORD 
    ); 
 
    public delegate uint GetNumberOfConsoleFonts(); 
 
    public delegate bool GetConsoleFontInfo( 
        IntPtr hWnd, 
        bool BOOL, 
        uint DWORD, 
        [Out] CONSOLE_FONT_INFO[] ConsoleFontInfo 
    ); 
 
 
    [StructLayout(LayoutKind.Sequential)] 
    public struct CONSOLE_FONT_INFO 
    { 
        public uint nFont; 
        public COORD dwFontSize; 
    } 
 
    [StructLayout(LayoutKind.Sequential)] 
    public struct COORD 
    { 
        public short X; 
        public short Y; 
    } 
 
    [DllImport("kernel32.dll")] 
    public static extern IntPtr GetModuleHandleA( 
        string module 
    ); 
 
    [DllImport("kernel32", CharSet=CharSet.Ansi, ExactSpelling=true, SetLastError=true)] 
    public static extern IntPtr GetProcAddress( 
        IntPtr hModule, 
        string procName 
        ); 
 
    [DllImport("kernel32.dll", SetLastError = true)] 
    public static extern IntPtr GetStdHandle( 
        int nStdHandle 
        ); 
 
    [DllImport("kernel32.dll", SetLastError = true)] 
    public static extern bool GetCurrentConsoleFont( 
        IntPtr hConsoleOutput, 
        bool bMaximumWindow, 
        out CONSOLE_FONT_INFO lpConsoleCurrentFont 
        ); 
"@ 
 
 
Add-Type -MemberDefinition $source  -Name Console -Namespace Win32API 
 
 
$_hmod = [Win32API.Console]::GetModuleHandleA("kernel32") 
 
"SetConsoleFont", "GetNumberOfConsoleFonts", "GetConsoleFontInfo" | 
    % { 
        $param = @() 
        $proc = [Win32API.Console]::GetProcAddress($_hmod, $_) 
        $delegate = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($proc, "Win32API.Console+$_") 
 
        $delegate.Invoke.OverloadDefinitions[0] -match "^[^(]+\((.*)\)" > $null 
        $argtypes = $Matches[1] -split ", " | 
            ? { $_ } | 
            % { 
                '[{0}] ${1}' -f ($_ -split " "); 
                $param += "$" + ($_ -split " ")[-1] 
            } 
        $argtypes = $argtypes -join ", " 
        $param = $param -join ", " 
        iex @" 
            function $_($argtypes){ 
                `$$_ = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($proc, 'Win32API.Console+$_') 
                `$$_.Invoke( $param ) 
            } 
"@ 
 
} 
 
$_hConsoleScreen = [Win32API.Console]::GetStdHandle($STD_OUTPUT_HANDLE) 
 
function Get-ConsoleFontInfo() 
{ 
    $_FontsNum = GetNumberOfConsoleFonts 
    $_ConsoleFonts = New-Object Win32API.Console+CONSOLE_FONT_INFO[] $_FontsNum 
 
    GetConsoleFontInfo $_hConsoleScreen $false $_FontsNum $_ConsoleFonts > $null 
 
    $_ConsoleFonts | select @{l="nFont";e={$_ConsoleFonts.Count-$_.nFont-1}}, @{l="dwFontSizeX";e={$_.dwFontSize.X}}, @{l="dwFontSizeY";e={$_.dwFontSize.Y}} | sort nFont 
 
} 
 
 
$_DefaultFont = New-Object Win32API.Console+CONSOLE_FONT_INFO 
[Win32API.Console]::GetCurrentConsoleFont($_hConsoleScreen, $true, [ref]$_DefaultFont) 
 
function Set-ConsoleFont ([Uint32]$DWORD=$_DefaultFont.nFont, [IntPtr]$hWnd=$_hConsoleScreen) 
{ 
    $flag = SetConsoleFont $hWnd $DWORD 
    if ( !$flag ) { throw "Illegal font index number. Check correct number using 'Get-ConsoleFontInfo'." } 
} 
 
 
 
Export-ModuleMember -Variable _DefaultFont, _hConsoleScreen -Function Set-ConsoleFont, Get-ConsoleFontInfo 