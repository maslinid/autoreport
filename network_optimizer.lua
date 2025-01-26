script_name('Network Optimizer')
script_version('1.0')
script_author('Papa_Neurowise')

require 'lib.moonloader'
local memory = require 'memory'
local ffi = require 'ffi'

-- ����� ������ ���������
local NETWORK_UPDATE_DELAY = 1000 -- ����������� �������� ����������
local PACKET_PRIORITY = 1 -- ������� ��������� (���� 2)
local MIN_BUFFER_SIZE = 8 -- ����������� ������ ������ (����)

ffi.cdef[[
    int SetPriorityClass(void* hProcess, unsigned long dwPriorityClass);
    void* GetCurrentProcess();
]]

-- ���������������� ������� ��� RakNet
function optimizeRakNet()
    local rakClient = memory.getint32(sampGetBase() + 0x26E8C4)
    if rakClient ~= 0 then
        -- ������� ���������
        memory.setint8(rakClient + 0x7A, PACKET_PRIORITY, true) -- ��������� �������
        memory.setint8(rakClient + 0x7B, 0, true) -- ��������� �������� ������
        memory.setint8(rakClient + 0x7C, MIN_BUFFER_SIZE, true) -- �����
    end
end

-- ������ ����������� SAMP
function optimizeSAMP()
    local sampBase = sampGetBase()
    if sampBase ~= 0 then
        -- ������� ����������� ��� ������������
        memory.setint8(sampBase + 0x119, 1, true)
    end
end

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    
    -- ������������� ���������� ���������
    ffi.C.SetPriorityClass(ffi.C.GetCurrentProcess(), 0x00000020) -- NORMAL_PRIORITY_CLASS
    
    -- �������� ����
    while true do
        wait(NETWORK_UPDATE_DELAY)
        optimizeRakNet()
        optimizeSAMP()
    end
end