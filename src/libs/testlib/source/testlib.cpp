
#include "testlib/testlib.h"

#include <fstream>
#include <iostream>
#include <limits>
#include <string>
#include <vector>

#include <cmake_template/cmake_template-version.h>

namespace testlib
{

void potentiallyDangerousFunction(int* ptr)
{
    if (ptr != nullptr) {
        *ptr = 10;
    }
    *ptr = 20; // CppCheck可能会警告潜在的空指针解引用
}

void cppCheckDemos()
{
    // 1. 未初始化的变量
    {
        int uninitializedVar;
        if (uninitializedVar == 0) {}
    }

    // 2. 数组越界访问
    {
        int array[5];
        for (int i = 0; i <= 5; i++) {
            array[i] = i;
        }
    }

    // 3. 向量越界访问
    {
        std::vector<int> vec(5);
        for (size_t i = 0; i <= vec.size(); i++) {
            vec[i] = i;
        }
    }
    // 4. 指针悬垂（Dangling pointer)
    {
        int* danglingPtr = new int(10);
        delete danglingPtr;
        *danglingPtr = 20; // CppCheck可能会警告悬垂指针的使用
    }

    // 5. 空指针解引用
    {
        int* nullPtr = nullptr;
        *nullPtr = 10;
    }

    // 6. 无效的内存释放
    {
        int* invalidFree = new int(10);
        free(invalidFree); // CppCheck会警告使用free()释放非malloc/calloc/realloc分配的内存
    }
    // 7. 整型溢出
    {
        int overflow = std::numeric_limits<int>::max();
        overflow += 1; // CppCheck会警告可能的整型溢出
    }
    // 8. 无效的转换
    {
        // void* voidPtr = reinterpret_cast<void*>(0xFFFFFFFFFFFFFFFF);
        // int invalidCast = static_cast<int>(voidPtr); // CppCheck会警告无效的类型转换
    }
    // 9. 潜在的空指针解引用  potentiallyDangerousFunction()
}

void printInfo()
{
    std::string dataPath = "data";

    // Library name
    std::cout << "Library cmake_template::testlib" << std::endl;
    std::cout << "========================================" << std::endl;

    // Library version
    std::cout << "Version: " << cmake_template::CMAKE_TEMPLATE_VERSION << std::endl;
    std::cout << std::endl;

// Library type (static or dynamic)
#ifdef TESTLIB_STATIC_DEFINE
    std::cout << "Library type: STATIC" << std::endl;
#else
    std::cout << "Library type: SHARED" << std::endl;
#endif

    // Data directory
    std::cout << "Data path:    " << dataPath << std::endl;
    std::cout << std::endl;

    // Read file
    std::cout << "Data directory access" << std::endl;
    std::cout << "========================================" << std::endl;

    std::string fileName = dataPath + "/DATA_FOLDER.txt";
    std::cout << "Reading from '" << fileName << "': " << std::endl;
    std::cout << std::endl;

    std::ifstream f(fileName);
    if (f.is_open()) {
        std::string line;
        while (getline(f, line)) {
            std::cout << line << '\n';
        }
        f.close();
    } else {
        std::cout << "Unable to open file." << std::endl;
    }
}

} // namespace testlib
